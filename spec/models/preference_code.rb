RSpec.describe PreferenceCode do
  subject { described_class.new }
  
  describe 'all' do
    it 'returns the list of preference codes' do
      number_of_codes = 28

      expect(subject.all.count).to eq(number_of_codes)
    end

    it 'has id and description' do
      expect(subject.all.first.keys).to include('id', 'description')
    end
  end
end
