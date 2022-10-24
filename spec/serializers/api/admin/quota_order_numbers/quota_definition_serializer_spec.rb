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
            validity_start_date: serializable.validity_start_date.iso8601,
            validity_end_date: nil,
            initial_volume: nil,
          },
          relationships: { quota_balance_events: { data: [] } },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
