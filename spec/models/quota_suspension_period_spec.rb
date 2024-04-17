RSpec.describe QuotaSuspensionPeriod do
  describe '.status' do
    it "returns 'Suspended' string" do
      expect(described_class.status).to eq('Suspended')
    end
  end
end
