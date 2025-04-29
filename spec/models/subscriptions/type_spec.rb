RSpec.describe Subscriptions::Type do
  it 'has the correct associations' do
    t = described_class.association_reflections[:subscriptions]
    expect(t[:type]).to eq(:one_to_many)
  end
end
