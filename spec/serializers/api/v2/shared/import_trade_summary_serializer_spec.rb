RSpec.describe Api::V2::Shared::ImportTradeSummarySerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) {
      Hashie::TariffMash.new(
        {
          id: '1',
          basic_third_country_duty: 'aaa',
          preferential_tariff_duty: 'bbb',
          preferential_quota_duty: 'ccc'
        }
      )
    }

    let(:expected_pattern) do
      {
        data: {
          attributes: {
            basic_third_country_duty: 'aaa',
            preferential_tariff_duty: 'bbb',
            preferential_quota_duty: 'ccc'
          },
          id: '1',
          type: :import_trade_summary
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
