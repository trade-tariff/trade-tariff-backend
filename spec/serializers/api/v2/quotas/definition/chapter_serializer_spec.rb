RSpec.describe Api::V2::Quotas::Definition::ChapterSerializer do
  it_behaves_like 'a serialized goods nomenclature', 'chapter' do
    let(:serializable) { create(:goods_nomenclature) }
  end
end
