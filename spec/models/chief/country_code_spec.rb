require 'rails_helper'

describe Chief::CountryCode do
  describe '.to_taric' do
    let!(:country_code) { create :country_code }
    let(:example_code) { Forgery(:basic).text }

    it 'maps CHIEF code to Taric' do
      expect(Chief::CountryCode.to_taric(country_code.chief_country_cd)).to eq country_code.country_cd
    end

    it 'is blank if no mapping is found' do
      expect(Chief::CountryCode.to_taric(example_code)).to be_blank
    end
  end
end
