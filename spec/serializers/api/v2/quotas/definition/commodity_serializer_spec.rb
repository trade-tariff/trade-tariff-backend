RSpec.describe Api::V2::Quotas::Definition::CommoditySerializer do
  it_behaves_like 'a serialized goods nomenclature', 'commodity' do
    let(:serializable) { create(:goods_nomenclature) }
  end
end
