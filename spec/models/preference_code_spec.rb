RSpec.describe PreferenceCode do
  subject(:preference_code) { described_class.new(id: '100', description: 'Erga Omnes third country duty rates') }

  it { expect(preference_code.id).to eq('100') }
  it { expect(preference_code.description).to eq('Erga Omnes third country duty rates') }
end
