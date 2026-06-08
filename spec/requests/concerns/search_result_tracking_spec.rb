RSpec.describe SearchResultTracking, :v2, type: :request do
  let(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter_and_heading,
      :with_measures,
      :with_description,
      :declarable,
    )
  end

  before do
    allow(Search::Instrumentation).to receive(:result_selected)
  end

  describe '#track_result_selected' do
    context 'when request_id is sent via X-Search-Request-Id header' do
      it 'fires the result_selected instrumentation event' do
        api_get api_commodity_path(commodity.code), headers: { 'X-Search-Request-Id' => 'req-abc-123' }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          request_id: 'req-abc-123',
          search_type: 'classic',
          goods_nomenclature_item_id: commodity.code,
          goods_nomenclature_class: 'Commodity',
        )
      end
    end

    context 'when request_id is sent via query param' do
      it 'falls back to the query param' do
        api_get api_commodity_path(commodity.code), params: { request_id: 'req-def-456' }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          request_id: 'req-def-456',
          search_type: 'classic',
          goods_nomenclature_item_id: commodity.code,
          goods_nomenclature_class: 'Commodity',
        )
      end
    end

    context 'when request_id is sent via both header and query param' do
      it 'prefers the header' do
        api_get api_commodity_path(commodity.code),
                params: { request_id: 'param-id' },
                headers: { 'X-Search-Request-Id' => 'header-id' }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          hash_including(request_id: 'header-id'),
        )
      end
    end

    context 'when no request_id is present' do
      it 'does not fire the result_selected event' do
        api_get api_commodity_path(commodity.code)

        expect(Search::Instrumentation).not_to have_received(:result_selected)
      end
    end
  end
end
