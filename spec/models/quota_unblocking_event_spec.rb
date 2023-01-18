RSpec.describe QuotaUnblockingEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Open')
    end
  end

  describe '#event_type' do
    subject(:quota_unblocking_event) { build(:quota_unblocking_event) }

    it 'returns event type string' do
      expect(quota_unblocking_event.event_type).to eq('Unblocking event')
    end
  end
end
