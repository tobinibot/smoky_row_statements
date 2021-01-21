# frozen_string_literal: true

require 'active_record'
require 'haml'
require 'zip'

require_relative 'zip_file_generator'

# CHROME_PATH = '~/Downloads/chrome-mac/Chromium.app/Contents/MacOS/Chromium'
CHROME_PATH = '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome'

GENERATE_PDF_COMMAND = "#{CHROME_PATH} --headless --print-to-pdf-no-header --print-to-pdf=pdfs/XXX.pdf XXX.html"

DONOR_NAMES_TO_IGNORE = [
  'Anonymous Giving', 'BWC', 'Spirit of Love Ministries',
  'Church of Pentecost USA Inc', 'Kroger Giving', 'Wesbanco',
  'Help My Neighbor Inc', 'WMO Class Settlement', 'Franklin County Ohio'
].freeze

# ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.default_timezone = :local

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: '127.0.0.1',
  port: 3306,
  database: 'smoky_row_giving',
  username: 'root',
  password: '',
  pool: 1
)

class Donor < ActiveRecord::Base
  def to_s
    full_name
  end
end

class Donation < ActiveRecord::Base
end

# cleanup
FileUtils.mkdir_p('pdfs')
FileUtils.rm(Dir.glob('pdfs/*.pdf'))

# Donation.all.each do |d|
#   if !DONOR_NAMES_TO_IGNORE.include?(d.donor_full_name) && Donor.where(full_name: d.donor_full_name).count != 1
#     puts "Missing a donor row for #{d.donor_full_name}"
#   end
# end
# exit(0)

Donor.all.each do |donor|
  donations = Donation.where(donor_full_name: donor.full_name).order(:date)

  next if donations.empty?

  td_accounts = donations.filter(&:tax_deductible).map(&:account).uniq
  ntd_accounts = donations.filter { |d| !d.tax_deductible }.map(&:account).uniq

  template = Haml::Engine.new(File.read('template.haml'))
  html = template.render(Object.new,
                         donor: donor,
                         donations: donations,
                         td_accounts: td_accounts,
                         ntd_accounts: ntd_accounts)

  safe_donor_name = donor.full_name.gsub(/\s+/, '_').gsub(/&/, 'and')
  html_file_name = "#{safe_donor_name}.html"

  File.write(html_file_name, html)
  system(GENERATE_PDF_COMMAND.gsub(/XXX/, safe_donor_name))
  FileUtils.rm(html_file_name)
end

# create a zip file
zf = ZipFileGenerator.new('pdfs', 'statements.zip')
zf.write