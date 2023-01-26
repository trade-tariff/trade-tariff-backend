RSpec.describe QuotaExhaustionEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Exhausted')
    end
  end

  describe '#event_type' do
    subject(:quota_exhaustion_event) { build(:quota_exhaustion_event) }

    it 'returns event type string' do
      expect(quota_exhaustion_event.event_type).to eq('Exhaustion event')
    end
  end
end
