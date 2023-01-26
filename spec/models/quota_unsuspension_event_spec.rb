RSpec.describe QuotaUnsuspensionEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Open')
    end
  end

  describe '#event_type' do
    subject(:quota_unsuspension_event) { build(:quota_unsuspension_event) }

    it 'returns event type string' do
      expect(quota_unsuspension_event.event_type).to eq('Unsuspension event')
    end
  end
end
