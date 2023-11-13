RSpec.describe ExchangeRateFile, type: :model do
  describe '#file_path' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }

    it { expect(exchange_rate_file.file_path).to eq('/api/v2/exchange_rates/files/monthly_csv_2023-6.csv') }
  end

  describe '#id' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }

    it { expect(exchange_rate_file.id).to be_present }
  end

  describe '#object_key' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }

    it { expect(exchange_rate_file.object_key).to eq('data/exchange_rates/2023/6/monthly_csv_2023-6.csv') }
  end

  describe '#filename' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }

    it { expect(exchange_rate_file.filename).to eq('monthly_csv_2023-6.csv') }
  end

  describe '.filepath_for' do
    let(:type) { 'monthly_csv' }
    let(:format) { 'csv' }
    let(:year) { 2023 }
    let(:month) { 7 }

    let(:expected_filepath) { "data/exchange_rates/#{year}/#{month}/monthly_csv_#{year}-#{month}.csv" }

    it 'returns the correct filepath' do
      expect(described_class.filepath_for(type, format, year, month)).to eq(expected_filepath)
    end
  end

  describe '.filename_for' do
    let(:type) { 'monthly_csv' }
    let(:format) { 'csv' }
    let(:year) { 2023 }
    let(:month) { 7 }

    let(:expected_filename) { "monthly_csv_#{year}-#{month}.csv" }

    it 'returns the correct filename' do
      expect(described_class.filename_for(type, format, year, month)).to eq(expected_filename)
    end
  end

  describe '.filename_for_download' do
    let(:type) { 'monthly_csv_hmrc' }
    let(:format) { 'csv' }
    let(:year) { '2023' }
    let(:month) { '09' }

    it 'returns the correct filename' do
      expect(described_class.filename_for_download(type, format, year, month)).to eq('202309MonthlyRates.csv')
    end
  end

  describe '.applicable_files_for' do
    before do
      expected_files
      create(:exchange_rate_file, period_month: month, period_year: year, type: 'monthly_xml_foo')
      create(:exchange_rate_file, period_month: month + 1, period_year: year + 1, type: 'monthly_csv')
    end

    let(:month) { 7 }
    let(:year) { 2023 }
    let(:expected_files) do
      create_list(
        :exchange_rate_file,
        1,
        period_month: month,
        period_year: year,
        type: 'monthly_xml',
      )
    end

    it { expect(described_class.applicable_files_for(month, year, ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE)).to match_array(expected_files) }

    it 'returns spot_csv files when type is spot' do
      spot_csv_files = create(:exchange_rate_file, period_month: month, period_year: year, type: 'spot_csv')
      expect(described_class.applicable_files_for(month, year, ExchangeRateCurrencyRate::SPOT_RATE_TYPE)).to match_array(spot_csv_files)
    end

    it 'returns average_csv files when type is average' do
      average_csv_files = create(:exchange_rate_file, period_month: month, period_year: year, type: 'average_csv')
      expect(described_class.applicable_files_for(month, year, ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE)).to match_array(average_csv_files)
    end
  end
end
