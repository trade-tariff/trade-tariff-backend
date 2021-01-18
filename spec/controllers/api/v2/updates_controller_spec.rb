require 'rails_helper'

describe Api::V2::UpdatesController, 'GET #latest' do
  render_views

  let(:pattern) do
    {
      data: [
        {
          id: String,
          type: 'tariff_update',
          attributes: {
            update_type: 'TariffSynchronizer::TaricUpdate',
            state: String,
            filename: String,
            created_at: String,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!,
      ].ignore_extra_values!,
    }
  end

  context 'when records are present' do
    it 'returns rendered records' do
      create :chief_update, :applied
      create :taric_update, :applied

      get :latest, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'when records are not present' do
    it 'returns blank array' do
      get :latest, format: :json

      expect(
        JSON.parse(response.body)['data'],
      ).to eq []
    end
  end
end
