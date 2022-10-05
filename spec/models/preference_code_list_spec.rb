RSpec.describe PreferenceCodeList do
  subject(:preference_code_list) { described_class }

  describe 'all' do
    it 'returns the list of preference codes' do
      number_of_codes = 28

      expect(preference_code_list.all.count).to eq(number_of_codes)
    end

    it 'has id and description' do
      expect(preference_code_list.all.first).to be_a(PreferenceCode)
    end
  end

  describe 'get' do
    it 'returns a code if one exists' do
      expect(preference_code_list.get(100).id).to eq('100')
    end

    it 'returns nil if code does not exist' do
      expect(preference_code_list.get(1000)).to eq(nil)
    end
  end
end
