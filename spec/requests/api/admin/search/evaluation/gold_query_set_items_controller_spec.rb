require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::GoldQuerySetItemsController, :admin do
  include GoldQueryItemHelper

  subject(:api_response) do
    make_request
    response
  end

  let(:gold_query_set) { create(:evaluation_gold_query_set) }

  def json_response = JSON.parse(api_response.body)

  def headers = { 'X-Whodunnit' => 'operator-1' }

  def item_ids
    json_response['data'].map { |row| row['id'] }
  end

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_items_path(gold_query_set.id, format: :json, **query) }
    let(:query) { {} }
    let(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'a made up search') }

    before do
      create_gold_query_item(gold_query_set, source_type: 'synthetic_atar', source_id: synthetic_atar.id.to_s, expected_code: '4201000000')
      create_gold_query_item(gold_query_set, source_type: 'atar', source_id: '600000002')
      create_gold_query_item(gold_query_set, source_type: 'atar', source_id: '600000001', queries: { 'emu_generic' => 'sheets' })
      create_gold_query_item(create(:evaluation_gold_query_set), source_id: '600000009')
    end

    it { is_expected.to have_http_status :ok }

    it 'lists one item for every three gold queries, ordered by source type and id' do
      expect(item_ids).to eq(%W[atar-600000001 atar-600000002 synthetic_atar-#{synthetic_atar.id}])
      expect(json_response['data'].map { |row| row['type'] }.uniq).to eq(%w[gold_query_set_item])
    end

    it 'gives each item the three persona queries and the shared fields' do
      attributes = json_response['data'].first['attributes']

      expect(attributes).to include(
        'gold_query_set_id' => gold_query_set.id,
        'source_type' => 'atar',
        'source_id' => '600000001',
        'expected_code' => '6302100000',
        'oracle_text' => 'Bed linen woven from cotton fabric, printed with a floral pattern.',
        'emu_generic_query' => 'sheets',
        'emu_ordinary_query' => 'emu_ordinary search',
        'emu_specific_query' => 'emu_specific search',
        'emu_generic_notes' => nil,
        'real_user_search' => nil,
      )
    end

    it 'gives the real user search of a synthetic ATaR item' do
      expect(json_response['data'].last['attributes']).to include('real_user_search' => 'a made up search', 'expected_code' => '4201000000')
    end

    it 'counts items, not rows, in the pagination meta' do
      expect(json_response.dig('meta', 'pagination')).to include('page' => 1, 'per_page' => 20, 'total_count' => 3)
    end

    context 'when asking for the second page of two' do
      let(:query) { { page: 2, per_page: 2 } }

      it 'returns the rest' do
        expect(item_ids).to eq(%W[synthetic_atar-#{synthetic_atar.id}])
      end
    end

    context 'when asking for a page past the end' do
      let(:query) { { page: 9 } }

      it { is_expected.to have_http_status :ok }
      it { expect(json_response['data']).to eq([]) }
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_items_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'GET #show' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-600000001', format: :json) }

    before { create_gold_query_item(gold_query_set) }

    it { is_expected.to have_http_status :ok }
    it { expect(json_response['data']['id']).to eq('atar-600000001') }
    it { expect(json_response['data']['attributes']['expected_code']).to eq('6302100000') }

    context 'when the item does not exist' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-1', format: :json) }

      it { is_expected.to have_http_status :not_found }
    end

    context 'when the item belongs to another set' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_item_path(create(:evaluation_gold_query_set).id, 'atar-600000001', format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'PATCH #update' do
    let(:make_request) { authenticated_patch api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-600000001', format: :json), params:, headers: }
    let(:params) { { data: { type: :gold_query_set_item, attributes: } } }
    let(:attributes) { { emu_generic_query: 'cotton sheets', emu_generic_notes: 'reworded', expected_code: '6302100090' } }

    before { create_gold_query_item(gold_query_set) }

    it { is_expected.to have_http_status :ok }

    it 'returns the item as saved' do
      expect(json_response['data']['attributes']).to include(
        'emu_generic_query' => 'cotton sheets',
        'emu_generic_notes' => 'reworded',
        'expected_code' => '6302100090',
        'emu_ordinary_query' => 'emu_ordinary search',
      )
    end

    it 'saves the expected code to all three rows' do
      api_response

      expect(EvaluationGoldQuery.where(set_id: gold_query_set.id).select_map(:expected_code)).to eq(%w[6302100090] * 3)
    end

    it 'records who made the change in the history' do
      api_response

      expect(Version.where(item_type: 'EvaluationGoldQuery', event: 'update').select_map(:whodunnit).uniq).to eq(%w[operator-1])
    end

    context 'when the body also carries fields that cannot be edited' do
      let(:attributes) { { emu_generic_query: 'cotton sheets', oracle_text: 'changed', source_id: '1', gold_query_set_id: 99, real_user_search: 'x' } }

      it 'ignores them' do
        api_response

        expect(EvaluationGoldQuery.select_map(:oracle_text).uniq).to eq(['Bed linen woven from cotton fabric, printed with a floral pattern.'])
        expect(EvaluationGoldQuery.select_map(:source_id).uniq).to eq(%w[600000001])
      end
    end

    context 'with a blank query' do
      let(:attributes) { { emu_ordinary_query: '', emu_generic_query: 'cotton sheets' } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first['source']['pointer']).to eq('/data/attributes/emu_ordinary_query') }
      it { expect(json_response['errors'].first['detail']).to eq('Emu ordinary query is not present') }

      it 'saves none of the changes' do
        api_response

        expect(EvaluationGoldQuery.where(query: 'cotton sheets').count).to eq(0)
      end
    end

    context 'with an expected code of the wrong length' do
      let(:attributes) { { expected_code: '63021' } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first).to include('title' => 'must be 6, 8 or 10 digits', 'source' => { 'pointer' => '/data/attributes/expected_code' }) }
    end

    context 'without the data envelope' do
      let(:params) { { emu_generic_query: 'cotton sheets' } }

      it { is_expected.to have_http_status :unprocessable_content }
    end

    context 'when the item does not exist' do
      let(:make_request) { authenticated_patch api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-1', format: :json), params:, headers: }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'DELETE #destroy' do
    let(:make_request) { authenticated_delete api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-600000001', format: :json) }

    before do
      create_gold_query_item(gold_query_set, source_id: '600000001')
      create_gold_query_item(gold_query_set, source_id: '600000002')
    end

    it { is_expected.to have_http_status :no_content }

    it 'deletes the three gold queries of that item and no others' do
      expect { api_response }.to change(EvaluationGoldQuery, :count).by(-3)
      expect(EvaluationGoldQuery.select_map(:source_id).uniq).to eq(%w[600000002])
    end

    it 'leaves the set counters alone, because they record what generation did' do
      expect { api_response }.not_to(change { EvaluationGoldQuerySet[gold_query_set.id].values })
    end

    context 'when the item does not exist' do
      let(:make_request) { authenticated_delete api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-1', format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'GET #versions' do
    let(:make_request) { authenticated_get versions_api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-600000001', format: :json) }

    before do
      create_gold_query_item(gold_query_set)
      create_gold_query_item(gold_query_set, source_id: '600000002')
      TradeTariffRequest.whodunnit = 'operator-1'
      Evaluation::GoldQueryItem.find(gold_query_set, 'atar-600000001').update(emu_specific_query: 'printed cotton sheets')
    end

    after { TradeTariffRequest.reset }

    it { is_expected.to have_http_status :ok }

    it 'lists the history of this item only, newest first' do
      versions = json_response['data'].map { |row| row['attributes'] }

      expect(versions.size).to eq(4)
      expect(versions.first).to include('event' => 'update', 'whodunnit' => 'operator-1')
      expect(versions.first['object']).to include('persona' => 'emu_specific', 'query' => 'printed cotton sheets')
      expect(versions.map { |version| version['object']['source_id'] }.uniq).to eq(%w[600000001])
    end

    it 'shows only the edited field in the changes' do
      expect(json_response['data'].first['attributes']['changeset']['changed_fields']).to eq(%w[query])
    end

    context 'when the item does not exist' do
      let(:make_request) { authenticated_get versions_api_admin_search_evaluation_gold_query_set_item_path(gold_query_set.id, 'atar-1', format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
