RSpec.describe Api::V2::MeasuresController do
  describe 'GET #search' do
    subject(:do_request) { get '/uk/api/measures/search', params:, headers: request_headers(format: :json) }

    let(:params) { {} }
    let(:json) { JSON.parse(response.body) }

    it 'is successful' do
      do_request
      expect(response).to be_successful
    end

    it 'returns data array' do
      do_request
      expect(json).to have_key('data')
    end

    it 'includes pagination meta' do
      do_request
      expect(json.dig('meta', 'pagination')).to include(
        'page' => 1,
        'per_page' => 25,
        'total_count' => 0,
      )
    end

    context 'when filtering by measure_type_series' do
      let!(:prohibition_measure) do
        create(:measure, measure_type_series_id: 'A')
      end

      let!(:other_measure) do
        create(:measure, measure_type_series_id: 'C')
      end

      let(:params) { { filter: { measure_type_series: %w[A] } } }

      before { do_request }

      it 'returns only measures in the requested series' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(prohibition_measure.measure_sid)
        expect(ids).not_to include(other_measure.measure_sid)
      end
    end

    context 'when filtering by geographical_area_id erga_omnes alias' do
      let!(:erga_omnes_measure) do
        create(:measure, geographical_area_id: GeographicalArea::ERGA_OMNES_ID)
      end

      let!(:country_measure) do
        create(:measure, geographical_area_id: 'CN')
      end

      let(:params) { { filter: { geographical_area_id: 'erga_omnes' } } }

      before { do_request }

      it 'returns only Erga Omnes measures' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(erga_omnes_measure.measure_sid)
        expect(ids).not_to include(country_measure.measure_sid)
      end
    end

    context 'when filtering with has_no_geographical_exclusions' do
      let!(:excluded_area) { create(:geographical_area, :with_description) }

      let!(:measure_with_exclusion) do
        create(:measure, excluded_geographical_areas: [excluded_area])
      end

      let!(:measure_without_exclusion) { create(:measure) }

      let(:params) { { filter: { has_no_geographical_exclusions: 'true' } } }

      before { do_request }

      it 'excludes measures that have geographical exclusions' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).not_to include(measure_with_exclusion.measure_sid)
        expect(ids).to include(measure_without_exclusion.measure_sid)
      end
    end

    context 'when filtering with has_no_exemption_conditions' do
      let!(:measure_with_exemption) do
        create(:measure, :with_measure_conditions,
               certificate_type_code: 'Y', certificate_code: '100')
      end

      let!(:measure_without_exemption) { create(:measure) }

      let(:params) { { filter: { has_no_exemption_conditions: 'true' } } }

      before { do_request }

      it 'excludes measures that have exemption conditions' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).not_to include(measure_with_exemption.measure_sid)
        expect(ids).to include(measure_without_exemption.measure_sid)
      end
    end

    context 'when filtering by commodity_code_prefix' do
      let!(:matching_measure) { create(:measure, goods_nomenclature_item_id: '0101210000') }
      let!(:other_measure) { create(:measure, goods_nomenclature_item_id: '0202100000') }

      let(:params) { { filter: { commodity_code_prefix: '01' } } }

      before { do_request }

      it 'returns only measures for the commodity prefix' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(matching_measure.measure_sid)
        expect(ids).not_to include(other_measure.measure_sid)
      end
    end

    context 'when paginating results' do
      before do
        create_list(:measure, 3, measure_type_series_id: 'A')
        get '/uk/api/measures/search',
            params: { filter: { measure_type_series: %w[A] }, per_page: 2, page: 1 },
            headers: request_headers(format: :json)
      end

      it 'returns the correct number of results per page' do
        expect(json['data'].length).to eq(2)
      end

      it 'reports the total count' do
        expect(json.dig('meta', 'pagination', 'total_count')).to eq(3)
      end
    end

    context 'when a measure has an excluded geographical area' do
      let!(:country) { create(:geographical_area, :country, :with_description) }
      let!(:measure) { create(:measure, excluded_geographical_areas: [country]) }

      before do
        get '/uk/api/measures/search',
            params: { filter: { measure_type_ids: [measure.measure_type_id] } },
            headers: request_headers(format: :json)
      end

      it 'includes excluded_geographical_area_ids in the response' do
        result = json['data'].find { |m| m['id'].to_i == measure.measure_sid }
        expect(result.dig('attributes', 'excluded_geographical_area_ids')).to include(country.geographical_area_id)
      end

      it 'flags has_geographical_exclusions as true' do
        result = json['data'].find { |m| m['id'].to_i == measure.measure_sid }
        expect(result.dig('attributes', 'has_geographical_exclusions')).to be(true)
      end
    end
  end
end
