RSpec.describe ExchangeRates::ExchangeRateFile do
  describe '#id' do
    let(:exchange_rate_file) { build(:exchange_rate_exchange_rate_file) }

    before do
      exchange_rate_file.period_year = 2023
      exchange_rate_file.period_month = 6
    end

    it 'returns the formatted exchange_rate_file ID' do
      expect(exchange_rate_file.id).to eq('2023-6-csv_file')
    end
  end

  describe '.build' do
    let(:file) { build(:exchange_rate_exchange_rate_file) }
    let(:exchange_rate_file) { described_class.build(file) }

    it 'builds a exchange_rate_file' do
      expect(exchange_rate_file).to be_a(described_class)
    end

    it 'builds a exchange_rate_file with correct attributes', :aggregate_failures do
      expect(exchange_rate_file.file_path).to eq(file.file_path)
      expect(exchange_rate_file.file_size).to eq(file.file_size)
      expect(exchange_rate_file.format).to eq(file.format)
    end
  end

  describe '.wrap' do
    let(:files) { build_list(:exchange_rate_exchange_rate_file, 1) }
    let(:exchange_rate_files) { described_class.wrap(files) }

    it 'builds an array of exchange_rate_files' do
      expect(exchange_rate_files).to be_an(Array)
    end

    it 'builds a exchange_rate_file with correct attributes', :aggregate_failures do
      exchange_rate_files.each do |exchange_rate_file|
        expect(exchange_rate_file.file_path).to be_in(files.first.file_path)
        expect(exchange_rate_file.file_size).to eq(files.first.file_size)
        expect(exchange_rate_file.format).to eq(files.first.format)
      end
    end
  end
end
