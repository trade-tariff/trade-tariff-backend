RSpec.describe PreferenceCode do
  subject { described_class }

  describe 'all' do
    it 'returns the list of preference codes' do
      number_of_codes = 28

      expect(subject.all.count).to eq(number_of_codes)
    end

    it 'has id and description' do
      expect(subject.all.first.keys).to include('id', 'description')
    end
  end

  describe 'get' do
    it 'returns the preference code attributes' do
      expect(subject.get(120)).to eq({
        'id' => '120',
        'description' => 'Non preferential tariff quotas',
      })
    end
  end
end
