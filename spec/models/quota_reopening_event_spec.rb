RSpec.describe QuotaReopeningEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Open')
    end
  end

  describe '#event_type' do
    subject(:quota_reopening_event) { build(:quota_reopening_event) }

    it 'returns event type string' do
      expect(quota_reopening_event.event_type).to eq('Reopening event')
    end
  end
end
