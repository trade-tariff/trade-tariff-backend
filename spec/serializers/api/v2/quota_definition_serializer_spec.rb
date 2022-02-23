RSpec.describe Api::V2::QuotaDefinitionSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:quota_definition) }

    let(:expected_pattern) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_definition,
          attributes: {
            critical_threshold: nil,
            initial_volume: nil,
            maximum_precision: nil,
            measurement_unit_code: serializable.measurement_unit_code,
            measurement_unit_qualifier_code: serializable.measurement_unit_qualifier_code,
            quota_order_number_id: serializable.quota_order_number_id,
            validity_end_date: nil,
            validity_start_date: 4.years.ago.beginning_of_day,
          },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
