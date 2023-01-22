# frozen_string_literal: true

require 'active_record'
require 'haml'
require 'zip'
require 'combine_pdf'

require_relative 'zip_file_generator'

# CHROME_PATH = '~/Downloads/chrome-mac/Chromium.app/Contents/MacOS/Chromium'
# CHROME_PATH = './chrome/Chromium.app/Contents/MacOS/Chromium'
CHROME_PATH = '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome'

GENERATE_PDF_COMMAND = "#{CHROME_PATH} --headless --print-to-pdf-no-header --print-to-pdf=pdfs/XXX.pdf XXX.html"

DONOR_NAMES_TO_IGNORE = [
  'Anonymous Giving', 'BWC', 'Spirit of Love Ministries',
  'Church of Pentecost USA Inc', 'Kroger Giving', 'Wesbanco',
  'Help My Neighbor Inc', 'WMO Class Settlement', 'Franklin County Ohio'
].freeze

ONLY_HTML = false

YEAR = 2022

# ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord.default_timezone = :local

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: '127.0.0.1',
  port: 5432,
  database: 'smoky_row_statements',
  username: 'root',
  password: '',
  pool: 1
)

class Donor < ActiveRecord::Base
  def to_s
    name
  end
end

class Donation < ActiveRecord::Base
end

# cleanup
FileUtils.mkdir_p("pdfs")
FileUtils.rm(Dir.glob("pdfs/*"))

YEAR_RANGE = Date.new(YEAR, 1, 1)..Date.new(YEAR + 1,1 , 1)

# Donation.where(date: YEAR_RANGE).each do |d|
#   if !DONOR_NAMES_TO_IGNORE.include?(d.donor_name) && Donor.where(name: d.donor_name).count != 1
#     puts "Missing a donor row for #{d.donor_name}"
#   end
# end
# exit(0)

generated_pdfs = []

template = Haml::Template.new('template.haml')

Donor.all.sort_by(&:name).each do |donor|
  next if DONOR_NAMES_TO_IGNORE.include?(donor.name)

  donations = Donation.where(donor_name: donor.name).where(date: YEAR_RANGE).order(:date)

  next if donations.empty?

  puts donor.name

  td_accounts = donations.filter(&:tax_deductible).map(&:account).uniq
  ntd_accounts = donations.filter { |d| !d.tax_deductible }.map(&:account).uniq

  html = template.render(Object.new,
                         donor: donor,
                         donations: donations,
                         td_accounts: td_accounts,
                         ntd_accounts: ntd_accounts)

  safe_donor_name = donor.name.gsub(/\s+/, '_').gsub(/&/, 'and')
  html_file_name = "#{safe_donor_name}.html"

  File.write(html_file_name, html)

  unless ONLY_HTML
    system(GENERATE_PDF_COMMAND.gsub(/XXX/, safe_donor_name))
    generated_pdfs << "#{safe_donor_name}.pdf"

    FileUtils.rm(html_file_name)
  end
end

unless ONLY_HTML
  # create a combined pdf file
  combined_pdf = CombinePDF.new
  generated_pdfs.each do |pdf|
    combined_pdf << CombinePDF.load("pdfs/#{pdf}")
  end
  combined_pdf.save("pdfs/_complete.pdf")

  # create a zip file
  zf = ZipFileGenerator.new("pdfs", 'statements.zip')
  zf.write
end