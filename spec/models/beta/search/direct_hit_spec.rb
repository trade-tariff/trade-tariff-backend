RSpec.describe Beta::Search::DirectHit do
  describe '#build' do
    shared_examples 'a direct hit' do |search_result|
      subject(:direct_hit) { described_class.build(search_result) }

      it { is_expected.to be_a(described_class) }
      it { expect(direct_hit.goods_nomenclature_class).to be_in(%w[Heading Chapter Subheading Commodity]) }
      it { expect(direct_hit.id).to match(/^[0-9]{10}-[0-9]{2}$/) }
      it { expect(direct_hit.goods_nomenclature_item_id).to match(/^[0-9]{10}$/) }
      it { expect(direct_hit.producline_suffix).to match(/^[0-9]{2}$/) }
      it { expect(direct_hit.search_references).to be_empty }
      it { expect(direct_hit.guides).to be_empty }
      it { expect(direct_hit.ancestors).to be_empty }
    end

    shared_examples 'not a direct hit' do |search_result|
      subject(:direct_hit) { described_class.build(search_result) }

      it { is_expected.to be_nil }
    end

    it_behaves_like 'a direct hit', FactoryBot.build(:search_result, :single_hit)
    it_behaves_like 'a direct hit', FactoryBot.build(:search_result, :with_search_reference)
    it_behaves_like 'a direct hit', FactoryBot.build(:search_result, :with_numeric_search_query)
    it_behaves_like 'not a direct hit', FactoryBot.build(:search_result, :multiple_hits)
    it_behaves_like 'not a direct hit', FactoryBot.build(:search_result, :no_hits)
  end
end