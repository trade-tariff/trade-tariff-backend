RSpec.describe Api::Internal::SearchExport::ResultClicksController do
  it 'stores a frontend click without a session id' do
    post "/#{TradeTariffBackend.service}/internal/search_export/result_clicks.json",
         params: { request_id: 'journey-1', goods_nomenclature_item_id: '0207141000', result_rank: 1 },
         headers: request_headers.merge('User-Agent' => 'TradeTariffFrontend/test'),
         as: :json

    expect(response).to have_http_status(:no_content)
    click = SearchExport::ResultClick.first
    expect(click.commodity_code).to eq('0207141000')
    expect(click.values.keys).not_to include(:browser_session_id)
  end

  it 'rejects an admin click' do
    post "/#{TradeTariffBackend.service}/internal/search_export/result_clicks.json",
         params: { request_id: 'journey-1', goods_nomenclature_item_id: '0207141000', result_rank: 1 },
         headers: request_headers.merge('User-Agent' => 'TradeTariffAdmin/test'),
         as: :json

    expect(response).to have_http_status(:forbidden)
    expect(SearchExport::ResultClick.count).to eq(0)
  end
end
