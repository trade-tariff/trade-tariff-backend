RSpec.describe GoodsNomenclatureIntercept do
  describe 'validations' do
    subject(:intercept) { build(:goods_nomenclature_intercept, **attrs) }

    let(:attrs) { {} }

    it 'is valid with the factory defaults' do
      expect(intercept).to be_valid
    end

    context 'when goods_nomenclature_sid is blank' do
      let(:attrs) { { goods_nomenclature_sid: nil } }

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:goods_nomenclature_sid]).to be_present
      end
    end
  end

  describe 'versioning' do
    it 'creates versions on create and update' do
      intercept = create(:goods_nomenclature_intercept)

      expect {
        intercept.update(message: 'Updated commodity guidance')
      }.to change { Version.where(item_type: 'GoodsNomenclatureIntercept', item_id: intercept.goods_nomenclature_sid.to_s).count }.by(1)

      expect(Version.where(item_type: 'GoodsNomenclatureIntercept', item_id: intercept.goods_nomenclature_sid.to_s).count).to eq(2)
    end
  end
end
