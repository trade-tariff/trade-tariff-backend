RSpec.describe Api::V2::ExchangeRates::ExchangeRateFileSerializer do
  subject(:serializable) { described_class.new(exchange_rate_file).serializable_hash }

  let(:exchange_rate_file) { build(:exchange_rate_file) }

  let :expected do
    {
      data: {
        id: exchange_rate_file.id,
        type: :exchange_rate_file,
        attributes: {
          file_path: exchange_rate_file.file_path,
          file_size: exchange_rate_file.file_size,
          format: exchange_rate_file.format,
          publication_date: exchange_rate_file.publication_date,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql(expected)
    end
  end
end
