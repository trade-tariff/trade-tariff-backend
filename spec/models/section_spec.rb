RSpec.describe Section do
  describe 'default ordering' do
    subject { described_class.all.pluck(:position) }

    before do
      create :section, position: 3, title: 'Section 3'
      create :section, position: 2, title: 'Section 2'
      create :section, position: 1, title: 'Section 1'
    end

    it { is_expected.to eql [1, 2, 3] }
  end

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
