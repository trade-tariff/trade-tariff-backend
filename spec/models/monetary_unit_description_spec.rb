RSpec.describe MonetaryUnitDescription do
  describe '#abbreviation' do
    context 'when abbreviation present for monetary unit code' do
      let(:monetary_unit_description) { build :monetary_unit_description, monetary_unit_code: 'EUC' }

      it 'returns the abbreviation' do
        expect(monetary_unit_description.abbreviation).to eq 'EUR (EUC)'
      end
    end

    context 'when abbreviation missing for monetary unit code' do
      let(:monetary_unit_description) { build :monetary_unit_description, monetary_unit_code: 'ERR' }

      it 'is blank' do
        expect(monetary_unit_description.abbreviation).to be_blank
      end
    end
  end
end
