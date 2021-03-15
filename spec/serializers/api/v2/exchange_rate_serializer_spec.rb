require 'rails_helper'

RSpec.describe Api::V2::Measures::ExchangeRateSerializer do
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable) { build(:exchange_rate) }

  let(:expected_pattern) do
    {
      data: {
        id: 'CAD',
        type: :exchange_rate,
        attributes: {
          rate: serializable.rate,
          base_currency: serializable.base_currency,
          applicable_date: serializable.applicable_date,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include(expected_pattern) }
  end
end
