RSpec.describe Api::V2::Shared::ImportTradeSummarySerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      import_measures = create_list(:measure, 1, :third_country, :erga_omnes, :with_measure_components)

      ImportTradeSummary.build(import_measures)
    end

    let(:expected_pattern) do
      {
        data: {
          id: String,
          type: :import_trade_summary,
          attributes: {
            basic_third_country_duty: String,
            preferential_tariff_duty: nil,
            preferential_quota_duty: nil,
          },
        },
      }
    end

    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
