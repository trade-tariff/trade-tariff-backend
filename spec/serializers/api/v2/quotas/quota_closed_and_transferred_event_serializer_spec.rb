RSpec.describe Api::V2::Quotas::QuotaClosedAndTransferredEventSerializer do
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable) { create(:quota_closed_and_transferred_event) }

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'quota_closed_and_transferred_event',
        attributes: {
          transferred_amount: be_a(Float),
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
  end
end
