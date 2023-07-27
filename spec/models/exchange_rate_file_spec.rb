require 'rails_helper'

RSpec.describe ExchangeRateFile, type: :model do
  describe '#file_path' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }
    let(:expected_file_path) { "/api/v2/exchange_rates/files.csv?month=#{exchange_rate_file.period_month}&year=#{exchange_rate_file.period_year}" }

    it 'returns the correct file path' do
      expect(exchange_rate_file.file_path).to eq(expected_file_path)
    end
  end

  describe '#id' do
    let(:exchange_rate_file) { build(:exchange_rate_file) }
    let(:expected_id) { "#{exchange_rate_file.period_year}-#{exchange_rate_file.period_month}-#{exchange_rate_file.format}-exchange_rate_file" }

    it 'returns the correct id' do
      expect(exchange_rate_file.id).to eq(expected_id)
    end
  end
end
