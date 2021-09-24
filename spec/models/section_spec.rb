RSpec.describe Section do
  describe 'associations' do
    describe 'chapters' do
      let!(:chapter) { create(:chapter, :with_section) }

      it 'does not include HiddenGoodsNomenclatures' do
        section = chapter.section
        create(:hidden_goods_nomenclature, goods_nomenclature_item_id: chapter.goods_nomenclature_item_id)

        expect(section.chapters).to eq []
      end
    end
  end
end
