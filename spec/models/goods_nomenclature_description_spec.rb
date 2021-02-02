require 'rails_helper'

describe GoodsNomenclatureDescription do
  describe '#description' do
    subject(:goods_nomenclature_description) { build :goods_nomenclature_description, description: description }

    context 'when the description value has multiple chained <br><br><br>tags' do
      let(:description) do
        'Additives containing<br> <br><br><br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br> <br><br><br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'replaces the chain of <br> tags with a single <br> tag' do
        expected = 'Additives containing<br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
        expect(goods_nomenclature_description.description).to eq(expected)
      end
    end

    context 'when the description value has only single <br> tag chains' do
      let(:description) do
        'Additives containing<br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'does not change the description' do
        expect(goods_nomenclature_description.description).to eq(description)
      end
    end

    context 'when the description value has no <br> tags' do
      let(:description) do
        'Additives containing - overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and - by weight more than 25 % but not more than 50 % of mineral oils,having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'does not change the description' do
        expect(goods_nomenclature_description.description).to eq(description)
      end
    end
  end

  describe '#to_s' do
    let(:gono_description) { build :goods_nomenclature_description }

    it 'is an alias for description' do
      expect(gono_description.to_s).to eq gono_description.description
    end
  end
end
