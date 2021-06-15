require 'rails_helper'

describe QuotaBalanceEvent do
  describe '.status' do
    it "returns 'open' string" do
      expect(described_class.status).to eq('Open')
    end
  end
end
