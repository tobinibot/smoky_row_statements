# frozen_string_literal: true

require 'active_record'
require 'pdfkit'
require 'haml'

CHROME_PATH = '~/Downloads/chrome-mac/Chromium.app/Contents/MacOS/Chromium'

GENERATE_PDF_COMMAND = "#{CHROME_PATH} --headless --print-to-pdf-no-header --print-to-pdf=pdfs/{name}.pdf {name}.html"

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

  safe_donor_name = donor.full_name.gsub(/\s+/, '')
  html_file_name = "#{safe_donor_name}.html"

  File.write(html_file_name, html)
  system(GENERATE_PDF_COMMAND.gsub(/\{name\}/, safe_donor_name))
  FileUtils.rm(html_file_name)
end

# system('./generate.sh')
# system('open TobinJuday_chrome.pdf')
