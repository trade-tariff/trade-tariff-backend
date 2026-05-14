RSpec.describe Api::Admin::FootnotesController do
  describe 'GET to #index' do
    let!(:non_national_footnote) { create(:footnote, :non_national, :with_description) }
    let!(:national_footnote) { create(:footnote, :national, :with_description) }
    let(:response_pattern) do
      {
        data: [{
          id: String,
          type: String,
          attributes: {
            footnote_id: String,
            footnote_type_id: String,
            validity_start_date: String,
            description: String,
          }.ignore_extra_keys!,
        }],
      }
    end
    let(:json_body) do
      JSON.parse(response.body)['data']
    end

    specify 'returns national footnote', :aggregate_failures do
      get '/uk/admin/footnotes.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression response_pattern
      expect(json_body.map { |f| f['id'] }).to include national_footnote.pk.join
    end

    specify 'does not return non-national footnote' do
      get '/uk/admin/footnotes.json', headers: request_headers(format: :json)

      expect(json_body.map { |f| f['id'] }).not_to include non_national_footnote.pk.join
    end
  end

  describe 'GET to #show' do
    let!(:non_national_footnote) { create(:footnote, :non_national, :with_description) }
    let!(:national_footnote) { create(:footnote, :national, :with_description) }

    let(:response_pattern) do
      {
        data: {
          id: String,
          type: String,
          attributes: {
            footnote_id: String,
            footnote_type_id: String,
            validity_start_date: String,
            description: String,
          }.ignore_extra_keys!,
        },
      }
    end

    specify 'returns national footnote' do
      get "/uk/admin/footnotes/#{national_footnote.pk.join}.json", headers: request_headers(format: :json)

      expect(response.body).to match_json_expression response_pattern
    end

    specify 'does not return non-national footnote' do
      get "/uk/admin/footnotes/#{non_national_footnote.pk.join}.json", headers: request_headers(format: :json)

      expect(response.status).to eq 404
    end
  end

  describe 'PUT to #update' do
    let!(:non_national_footnote) { create(:footnote, :non_national, :with_description) }
    let!(:national_footnote) { create(:footnote, :national, :with_description) }

    specify 'updates national footnote' do
      expect {
        put "/uk/admin/footnotes/#{national_footnote.pk.join}.json", params: { data: { type: :footnote, attributes: { description: 'new description' } } }, headers: request_headers(format: :json), as: :json
        FootnoteDescription.refresh!
      }.to change { national_footnote.reload.description }.to('new description')
    end

    specify 'does not update non-national footnote' do
      put "/uk/admin/footnotes/#{non_national_footnote.pk.join}.json", params: { data: {} }, headers: request_headers(format: :json), as: :json

      expect(response.status).to eq 404
    end
  end
end
