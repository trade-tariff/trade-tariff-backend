RSpec.describe 'exchange_rates_mailer/monthly_files', type: :view do
  let(:date) { Date.new(2023, 7, 15) }
  let!(:exchange_rate_file_csv_hmrc) { create(:exchange_rate_file, type: 'monthly_csv_hmrc', period_month: date.month, period_year: date.year) }

  before do
    assign(:month_and_year, date.next_month.strftime('%B %Y'))
    assign(:csv_hmrc, exchange_rate_file_csv_hmrc)
    render
  end

  context 'with correct email body content' do
    it { expect(rendered).to include("Please use the following link to download the exchange rate file for #{date.next_month.strftime('%B %Y')}.") }
    it { expect(rendered).to include("<a href=\"#{TradeTariffBackend.frontend_host + exchange_rate_file_csv_hmrc.file_path}\">CSV HMRC link</a>") }
  end
end
