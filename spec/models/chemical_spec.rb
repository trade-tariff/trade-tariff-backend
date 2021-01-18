require 'rails_helper'

describe Chemical do
  describe 'associations' do
    let!(:goods_nomenclature) { create(:goods_nomenclature) }
    let!(:goods_nomenclature_alt) { create(:goods_nomenclature) }
    let!(:chemical) { create(:chemical, :with_name) }

    describe 'chemical_names' do
      it 'has a name' do
        expect(chemical.name).to be_a(String)
      end

      it 'can have two names' do
        chemical.add_chemical_name({ name: 'water' })
        expect(chemical.chemical_names.count).to eq 2
        expect(chemical.name).to include('water')
      end
    end

    describe 'goods_nomenclatures' do
      it 'has one goods_nomenclature' do
        create(:chemicals_goods_nomenclatures, chemical_id: chemical.id, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        expect(chemical.goods_nomenclatures.count).to eq 1
      end

      it 'can have two goods_nomenclatures' do
        create(:chemicals_goods_nomenclatures, chemical_id: chemical.id, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        create(:chemicals_goods_nomenclatures, chemical_id: chemical.id, goods_nomenclature_sid: goods_nomenclature_alt.goods_nomenclature_sid)
        expect(chemical.goods_nomenclatures.count).to eq 2
      end
    end
  end
end
