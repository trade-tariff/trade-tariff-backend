require 'rails_helper'

RSpec.describe 'exchange_rates_mailer/monthly_files', type: :view do
  let(:date) { Date.new(2023, 7, 15) }
  let!(:exchange_rate_file_csv_hmrc) { create(:exchange_rate_file, type: 'monthly_csv_hmrc', period_month: date.month, period_year: date.year) }
  let!(:exchange_rate_file_xml) { create(:exchange_rate_file, type: 'monthly_xml', period_month: date.month, period_year: date.year) }

  before do
    assign(:month_and_year, date.next_month.strftime('%B %Y'))
    assign(:csv_hmrc, exchange_rate_file_csv_hmrc)
    assign(:xml, exchange_rate_file_xml)
    render
  end

  context 'with correct email body content' do
    it { expect(rendered).to include("Please use the following links to download the exchange rate files for #{date.next_month.strftime('%B %Y')}.") }
    it { expect(rendered).to include("<a href=\"#{TradeTariffBackend.frontend_host + exchange_rate_file_csv_hmrc.file_path}\">CSV HMRC link</a>") }
    it { expect(rendered).to include("<a href=\"#{TradeTariffBackend.frontend_host + exchange_rate_file_xml.file_path}\">XML link</a>") }
  end
end