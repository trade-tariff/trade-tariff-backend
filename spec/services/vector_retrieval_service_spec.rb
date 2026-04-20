RSpec.describe VectorRetrievalService do
  subject(:service) { described_class.new(query: 'live horses', limit: 10) }

  let(:embedding_service) { instance_double(EmbeddingService) }
  let(:query_embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  before do
    allow(EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(embedding_service).to receive(:embed).with('live horses').and_return(query_embedding)
  end

  describe '#call' do
    it 'embeds the query text' do
      service.call

      expect(embedding_service).to have_received(:embed).with('live horses')
    end

    it 'returns results with ORM-derived fields', :aggregate_failures do
      commodity = create(:commodity, :with_description, :declarable,
                         goods_nomenclature_item_id: '0101210000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             self_text: 'Pure-bred breeding horses')

      populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)

      results = service.call

      expect(results).not_to be_empty

      result = results.first
      expect(result.goods_nomenclature_item_id).to eq('0101210000')
      expect(result.goods_nomenclature_sid).to eq(commodity.goods_nomenclature_sid)
      expect(result.producline_suffix).to eq('80')
      expect(result.goods_nomenclature_class).to eq('Commodity')
      expect(result.declarable).to be true
      expect(result.score).to be_a(Float)
      expect(result.confidence).to be_nil
      expect(result.description).to be_present
      expect(result.formatted_description).to be_present
      expect(result.full_description).to be_present
    end

    it 'excludes non-declarable goods nomenclatures by default' do
      heading = create(:heading, :with_description, :non_declarable,
                       goods_nomenclature_item_id: '0101000000',
                       producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             self_text: 'Live horses heading')

      populate_search_embedding(heading.goods_nomenclature_sid, query_embedding)

      results = service.call

      expect(results).to be_empty
    end

    context 'when search_non_declarables is enabled' do
      before do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('search_non_declarables').and_return(true)
      end

      it 'includes non-declarable goods nomenclatures' do
        heading = create(:heading, :with_description, :non_declarable,
                         goods_nomenclature_item_id: '0101000000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               self_text: 'Live horses heading')

        populate_search_embedding(heading.goods_nomenclature_sid, query_embedding)

        results = service.call

        expect(results).not_to be_empty
        expect(results.first.declarable).to be false
      end
    end

    it 'excludes hidden goods nomenclatures' do
      commodity = create(:commodity, :with_description, :declarable, :hidden,
                         goods_nomenclature_item_id: '0101210000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             self_text: 'Hidden commodity')

      populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)

      results = service.call

      expect(results).to be_empty
    end

    it 'excludes records without search_embedding' do
      commodity = create(:commodity, :with_description, :declarable,
                         goods_nomenclature_item_id: '0101210000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             self_text: 'No embedding')

      results = service.call

      expect(results).to be_empty
    end

    it 'excludes expired goods nomenclatures' do
      commodity = create(:commodity, :with_description, :declarable,
                         goods_nomenclature_item_id: '0101210000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX,
                         validity_end_date: 1.year.ago)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
             self_text: 'Expired commodity')

      populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)

      results = service.call

      expect(results).to be_empty
    end

    context 'when score threshold filtering is applied' do
      before do
        allow(AdminConfiguration).to receive(:integer_value).and_call_original
        allow(AdminConfiguration).to receive(:integer_value).with('vector_score_threshold').and_return(30)
      end

      it 'includes results above the threshold' do
        commodity = create(:commodity, :with_description, :declarable,
                           goods_nomenclature_item_id: '0101210000',
                           producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'Pure-bred breeding horses')

        populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)

        results = service.call

        expect(results).not_to be_empty
      end

      it 'excludes results below the threshold' do
        commodity = create(:commodity, :with_description, :declarable,
                           goods_nomenclature_item_id: '0101210000',
                           producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'Pure-bred breeding horses')

        populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)

        # Identical embeddings produce a perfect cosine similarity of 1.0,
        # so threshold must exceed 100 to filter them out
        allow(AdminConfiguration).to receive(:integer_value).with('vector_score_threshold').and_return(101)

        results = service.call

        expect(results).to be_empty
      end
    end

    it 'respects the limit parameter' do
      3.times do |i|
        code = "010121000#{i}"
        commodity = create(:commodity, :with_description, :declarable,
                           goods_nomenclature_item_id: code,
                           producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: "Commodity #{i}")

        populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)
      end

      limited_service = described_class.new(query: 'live horses', limit: 2)
      results = limited_service.call

      expect(results.size).to eq(2)
    end

    context 'with filter prefixes' do
      subject(:service) { described_class.new(query: 'live horses', limit: 10, filter_prefixes: %w[0101]) }

      it 'only returns goods nomenclatures matching the prefixes' do
        matching = create(:commodity, :with_description, :declarable,
                          goods_nomenclature_item_id: '0101210000',
                          producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)
        non_matching = create(:commodity, :with_description, :declarable,
                              goods_nomenclature_item_id: '0201210000',
                              producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        [matching, non_matching].each do |commodity|
          create(:goods_nomenclature_self_text,
                 goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                 goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                 self_text: 'Pure-bred breeding horses')
          populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)
        end

        expect(service.call.map(&:goods_nomenclature_item_id)).to eq(%w[0101210000])
      end
    end
  end

  private

  def populate_search_embedding(sid, embedding)
    vector_literal = "'[#{embedding.join(',')}]'::vector"
    Sequel::Model.db.run(
      "UPDATE goods_nomenclature_self_texts SET search_embedding = #{vector_literal} WHERE goods_nomenclature_sid = #{sid}",
    )
  end
end
