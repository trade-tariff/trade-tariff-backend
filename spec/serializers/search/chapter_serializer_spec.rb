RSpec.describe Search::ChapterSerializer do
  describe '#to_json' do
    subject(:serialized) { described_class.new(serializable).to_json }

    let(:serializable) { create(:chapter, :with_section, :with_description) }

    let(:pattern) do
      {
        goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
        section: Hash,
        description: serializable.formatted_description,
        description_indexed: serializable.description_indexed,
      }.ignore_extra_keys!
    end

    it { is_expected.to match_json_expression pattern }
  end
end
