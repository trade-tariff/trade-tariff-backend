require 'rails_helper'

RSpec.describe ExchangeRates::CreateCsvSpotService do
  subject(:create_csv) { described_class.call(data) }

  let(:data) do
    [
      OpenStruct.new(
        country_description: 'Australia',
        currency_description: 'Dollar',
        currency_code: 'AUD',
        rate: 1.8464,
      ),
      OpenStruct.new(
        country_description: 'Canada',
        currency_description: 'Dollar',
        currency_code: 'CAD',
        rate: 1.6753,
      ),
    ]
  end

  let(:parsed_csv) do
    "Country,Unit Of Currency,Currency Code,Sterling value of Currency Unit £,Currency Units per £1\n" \
    "Australia,Dollar,AUD,0.5415944540727903,1.8464\n" \
    "Canada,Dollar,CAD,0.5969080164746613,1.6753\n"
  end

  it { is_expected.to eq(parsed_csv) }
end
