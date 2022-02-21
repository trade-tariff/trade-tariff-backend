RSpec.describe Api::V2::QuotaOrderNumberSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:quota_order_number, :with_quota_definition) }

    let(:expected_pattern) do
      {
        data: {
          id: serializable.quota_order_number_id.to_s,
          type: :quota_order_number,
          attributes: {
            quota_order_number_sid: serializable.quota_order_number_sid,
            validity_end_date: nil,
            validity_start_date: Date.current.ago(4.years),
          },
          relationships: {
            quota_definition: { data: { id: serializable.quota_definition_id.to_s, type: :quota_definition } },
          },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
