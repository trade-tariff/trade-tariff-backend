require 'rails_helper'

describe Chief::CountryGroup do
  describe '.to_taric' do
    let!(:country_group) { create :country_group }
    let(:example_code)  { Forgery(:basic).text }

    it 'maps CHIEF code to Taric' do
      expect(
        Chief::CountryGroup.to_taric(country_group.chief_country_grp),
      ).to eq country_group.country_grp_region
    end

    it 'is blank if no mapping is found' do
      expect(Chief::CountryGroup.to_taric(example_code)).to be_blank
    end
  end
end
