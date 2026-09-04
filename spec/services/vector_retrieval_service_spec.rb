RSpec.describe VectorRetrievalService do
  subject(:service) { described_class.new(query: 'live horses', limit: 10, request_id: 'request-123') }

  let(:embedding_service) { instance_double(EmbeddingService) }
  let(:query_embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  before do
    allow(EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(embedding_service).to receive(:embed).with('live horses', event_kind: 'vector_search_query_embedding').and_return(query_embedding)
  end

  describe '#call' do
    it 'embeds the query text' do
      service.call

      expect(embedding_service).to have_received(:embed).with('live horses', event_kind: 'vector_search_query_embedding')
    end

    it 'instruments the query embedding call with AI usage metadata' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('embedding_api_call_completed.ai_usage') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      service.call

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        event_kind: 'vector_search_query_embedding',
        batch_size: 1,
        model: EmbeddingService::MODEL,
        request_id: 'request-123',
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
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

    it 'excludes non-declarable candidates from the diagnostic maximum score' do
      heading = create(:heading, :with_description, :non_declarable,
                       goods_nomenclature_item_id: '0101000000',
                       producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             self_text: 'Live horses heading')

      populate_search_embedding(heading.goods_nomenclature_sid, query_embedding)

      result = service.call_with_diagnostics

      expect(result.results).to be_empty
      expect(result.max_score).to be_nil
    end

    it 'does not query eligibility when vector search returns no candidates' do
      allow(GoodsNomenclature).to receive(:actual).and_call_original

      result = service.call_with_diagnostics

      expect(result.results).to be_empty
      expect(result.max_score).to be_nil
      expect(GoodsNomenclature).not_to have_received(:actual)
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
        allow(GoodsNomenclature).to receive(:actual).and_call_original

        results = service.call

        expect(results).to be_empty
        expect(GoodsNomenclature).not_to have_received(:actual)
      end

      it 'exposes the maximum raw score before candidate filtering for hybrid query controls' do
        commodity = create(:commodity, :with_description, :declarable,
                           goods_nomenclature_item_id: '0101210000',
                           producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'Pure-bred breeding horses')

        populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)
        allow(AdminConfiguration).to receive(:integer_value).with('vector_score_threshold').and_return(101)

        sql = []
        subscriber = ActiveSupport::Notifications.subscribe(/sql\.sequel/) do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          sql << event.payload[:sql].to_s
        end

        begin
          result = service.call_with_diagnostics
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        expect(result.results).to be_empty
        expect(result.max_score).to be_within(0.0001).of(1.0)
        expect(sql.grep(/goods_nomenclature_descriptions|goods_nomenclature_description_periods/i)).to be_empty
      end

      it 'uses the highest eligible raw score across multiple candidates' do
        low_score_commodity = create(:commodity, :with_description, :declarable,
                                     goods_nomenclature_item_id: '0101210001',
                                     producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)
        high_score_commodity = create(:commodity, :with_description, :declarable,
                                      goods_nomenclature_item_id: '0101210002',
                                      producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)

        [low_score_commodity, high_score_commodity].each do |commodity|
          create(:goods_nomenclature_self_text,
                 goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                 goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                 self_text: 'Pure-bred breeding horses')
        end

        populate_search_embedding(low_score_commodity.goods_nomenclature_sid, query_embedding.map(&:-@))
        populate_search_embedding(high_score_commodity.goods_nomenclature_sid, query_embedding)
        allow(AdminConfiguration).to receive(:integer_value).with('vector_score_threshold').and_return(101)

        result = described_class.call_with_diagnostics(query: 'live horses')

        expect(result.results).to be_empty
        expect(result.max_score).to be_within(0.0001).of(1.0)
      end
    end

    context 'when overrides are passed explicitly' do
      it 'uses the given vector_score_threshold instead of reading AdminConfiguration' do
        commodity = create(:commodity, :with_description, :declarable,
                           goods_nomenclature_item_id: '0101210000',
                           producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'Pure-bred breeding horses')
        populate_search_embedding(commodity.goods_nomenclature_sid, query_embedding)
        allow(AdminConfiguration).to receive(:integer_value).and_call_original

        service = described_class.new(query: 'live horses', limit: 10, request_id: 'request-123', vector_score_threshold: 101)
        results = service.call

        expect(results).to be_empty
        expect(AdminConfiguration).not_to have_received(:integer_value).with('vector_score_threshold')
      end

      it 'uses the given search_non_declarables instead of reading AdminConfiguration' do
        heading = create(:heading, :with_description, :non_declarable,
                         goods_nomenclature_item_id: '0101000000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               self_text: 'Live horses heading')
        populate_search_embedding(heading.goods_nomenclature_sid, query_embedding)
        allow(AdminConfiguration).to receive(:enabled?).and_call_original

        service = described_class.new(query: 'live horses', limit: 10, request_id: 'request-123', search_non_declarables: true)
        results = service.call

        expect(results).not_to be_empty
        expect(AdminConfiguration).not_to have_received(:enabled?).with('search_non_declarables')
      end

      it 'uses the given search_non_declarables: false instead of reading AdminConfiguration' do
        heading = create(:heading, :with_description, :non_declarable,
                         goods_nomenclature_item_id: '0101000000',
                         producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX)
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               self_text: 'Live horses heading')
        populate_search_embedding(heading.goods_nomenclature_sid, query_embedding)
        # Stub AdminConfiguration to say non-declarables SHOULD be included, so that a
        # regression to `@search_non_declarables || AdminConfiguration.enabled?(...)`
        # (which treats `false` as "not given" because `false` is falsy in Ruby) would
        # incorrectly fall through to this stub and include the non-declarable heading.
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('search_non_declarables').and_return(true)

        service = described_class.new(query: 'live horses', limit: 10, request_id: 'request-123', search_non_declarables: false)
        results = service.call

        expect(results).to be_empty
        expect(AdminConfiguration).not_to have_received(:enabled?).with('search_non_declarables')
      end

      it 'uses the given vector_ef_search instead of reading AdminConfiguration' do
        allow(AdminConfiguration).to receive(:integer_value).and_call_original

        service = described_class.new(query: 'live horses', limit: 10, request_id: 'request-123', vector_ef_search: 200)
        service.call

        expect(AdminConfiguration).not_to have_received(:integer_value).with('vector_ef_search')
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

  describe '#call_with_diagnostics' do
    context 'when embedding generation fails' do
      before do
        allow(embedding_service).to receive(:embed).and_raise(Faraday::TimeoutError)
      end

      it 'identifies the embedding boundary' do
        expect { service.call_with_diagnostics }
          .to raise_error(described_class::EmbeddingGenerationError)
      end
    end

    context 'when vector retrieval fails' do
      before do
        allow(GoodsNomenclatureSelfText).to receive(:vector_search).and_raise(Sequel::DatabaseError)
      end

      it 'identifies the retrieval boundary' do
        expect { service.call_with_diagnostics }
          .to raise_error(described_class::VectorRetrievalError)
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
