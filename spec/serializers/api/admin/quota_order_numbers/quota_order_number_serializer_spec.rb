RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaOrderNumberSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_order_number) }

    let(:expected) do
      {
        data: {
          id: match(/09\d+/),
          type: eq(:quota_order_number),
          attributes: {
            quota_order_number_sid: be_a(Integer),
            validity_start_date: serializable.validity_start_date.iso8601,
            validity_end_date: nil,
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end
