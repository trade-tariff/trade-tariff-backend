RSpec.describe Sequel::Model do
  describe 'association datasets' do
    subject(:cached_association) do
      Commodity.association_reflections[:goods_nomenclature_descriptions][:cache]
    end

    before do
      Commodity.by_code(commodity.goods_nomenclature_item_id)
               .eager(:goods_nomenclature_descriptions)
               .take
    end

    let(:commodity) { create :commodity }

    it 'remain uncached' do
      expect(cached_association).to be_nil
    end
  end
end
