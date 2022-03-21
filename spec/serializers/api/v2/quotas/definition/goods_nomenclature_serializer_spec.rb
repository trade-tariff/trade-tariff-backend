RSpec.describe Api::V2::Quotas::Definition::GoodsNomenclatureSerializer do
  it_behaves_like 'a serialized goods nomenclature', 'goods_nomenclature' do
    let(:serializable) { create(:goods_nomenclature) }
  end
end
