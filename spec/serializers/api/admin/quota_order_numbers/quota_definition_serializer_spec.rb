RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaDefinitionSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_definition) }

    let(:expected) do
      {
        data: {
          id: match(/\d+/),
          type: eq(:quota_definition),
          attributes: {
            validity_start_date: serializable.validity_start_date.iso8601,
            validity_end_date: nil,
            initial_volume: nil,
            quota_order_number_id: serializable.quota_order_number_id,
            quota_type: 'First Come First Served',
            critical_state: 'N',
            critical_threshold: serializable.critical_threshold,
            measurement_unit: nil,
          },
          relationships: {
            quota_order_number: { data: { id: serializable.quota_order_number_id, type: eq(:quota_order_number) } },
            quota_balance_events: { data: [] },
            quota_order_number_origins: { data: [] },
            quota_unsuspension_events: { data: [] },
            quota_reopening_events: { data: [] },
            quota_unblocking_events: { data: [] },
            quota_exhaustion_events: { data: [] },
            quota_critical_events: { data: [] },
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end
