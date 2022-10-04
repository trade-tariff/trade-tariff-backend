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
end
