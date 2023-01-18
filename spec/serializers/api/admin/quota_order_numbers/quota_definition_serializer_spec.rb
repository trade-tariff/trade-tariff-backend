RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaDefinitionSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_definition) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_definition,
          attributes: {
            measurement_unit: serializable.formatted_measurement_unit,
            quota_order_number_id: serializable.quota_order_number_id,
            validity_start_date: serializable.validity_start_date.iso8601,
            validity_end_date: nil,
            initial_volume: nil,
            quota_type: 'First Come First Served',
            critical_state: serializable.critical_state,
            critical_threshold: serializable.critical_threshold,
          },
          relationships: { quota_balance_events: { data: [] },
                           quota_order_number_origins: { data: [] },
                           quota_unsuspension_events: { data: [] },
                           quota_reopening_events: { data: [] },
                         },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
