RSpec.describe QuotaSuspensionPeriod do
  describe '.status' do
    it "returns 'Suspended' string" do
      expect(described_class.status).to eq(QuotaDefinition::STATUS_SUSPENDED)
    end
  end
end
