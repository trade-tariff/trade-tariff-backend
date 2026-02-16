RSpec.describe SearchResultTracking, type: :controller do
  controller(Api::V2::CommoditiesController) {}

  routes { V2Api.routes }

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
        request.headers['X-Search-Request-Id'] = 'req-abc-123'
        get :show, params: { id: commodity.code }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          request_id: 'req-abc-123',
          goods_nomenclature_item_id: commodity.code,
          goods_nomenclature_class: 'Commodity',
        )
      end
    end

    context 'when request_id is sent via query param' do
      it 'falls back to the query param' do
        get :show, params: { id: commodity.code, request_id: 'req-def-456' }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          request_id: 'req-def-456',
          goods_nomenclature_item_id: commodity.code,
          goods_nomenclature_class: 'Commodity',
        )
      end
    end

    context 'when request_id is sent via both header and query param' do
      it 'prefers the header' do
        request.headers['X-Search-Request-Id'] = 'header-id'
        get :show, params: { id: commodity.code, request_id: 'param-id' }

        expect(Search::Instrumentation).to have_received(:result_selected).with(
          hash_including(request_id: 'header-id'),
        )
      end
    end

    context 'when no request_id is present' do
      it 'does not fire the result_selected event' do
        get :show, params: { id: commodity.code }

        expect(Search::Instrumentation).not_to have_received(:result_selected)
      end
    end
  end
end
