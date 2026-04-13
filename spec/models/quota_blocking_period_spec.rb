RSpec.describe QuotaBlockingPeriod do
  describe '.status' do
    it "returns 'Blocked' string" do
      expect(described_class.status).to eq(QuotaDefinition::STATUS_BLOCKED)
    end
  end
end
