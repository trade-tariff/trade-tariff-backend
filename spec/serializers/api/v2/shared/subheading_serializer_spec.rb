RSpec.describe Api::V2::Shared::SubheadingSerializer do
  it_behaves_like 'a serialized goods nomenclature', 'subheading' do
    let(:serializable) { create(:goods_nomenclature) }
  end
end
