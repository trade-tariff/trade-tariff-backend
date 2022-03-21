RSpec.describe Api::V2::Quotas::Definition::HeadingSerializer do
  it_behaves_like 'a serialized goods nomenclature', 'heading' do
    let(:serializable) { create(:goods_nomenclature) }
  end
end
