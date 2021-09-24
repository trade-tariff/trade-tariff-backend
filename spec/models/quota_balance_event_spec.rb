RSpec.describe QuotaBalanceEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Open')
    end
  end

  describe '#id' do
    subject(:event) { build(:quota_balance_event, quota_definition_sid: 1, occurrence_timestamp: now) }

    let(:now) { Time.zone.now }

    it 'returns a correctly formatted id' do
      expect(event.id).to eq("1-#{now.iso8601}")
    end
  end
end
