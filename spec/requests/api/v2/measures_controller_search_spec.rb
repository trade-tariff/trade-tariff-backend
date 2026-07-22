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

    context 'when filtering by measure_condition_codes' do
      let!(:licensed_measure) do
        create(:measure, :with_measure_conditions, condition_code: 'B')
      end
      let!(:unlicensed_measure) { create(:measure) }

      let(:params) { { filter: { measure_condition_codes: %w[B] } } }

      before { do_request }

      it 'returns only measures with the specified condition code' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(licensed_measure.measure_sid)
        expect(ids).not_to include(unlicensed_measure.measure_sid)
      end
    end

    context 'when filtering by regulation_id' do
      let(:regulation_id) { 'R0101234' }
      let!(:target_measure) { create(:measure, measure_generating_regulation_id: regulation_id) }
      let!(:other_measure) { create(:measure) }

      let(:params) { { filter: { regulation_id: } } }

      before { do_request }

      it 'returns only measures for the regulation' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(target_measure.measure_sid)
        expect(ids).not_to include(other_measure.measure_sid)
      end
    end

    context 'when filtering by has_ad_valorem' do
      let!(:ad_valorem_measure) do
        create(:measure, :with_measure_components, monetary_unit_code: nil, measurement_unit_code: nil,
                                                   measurement_unit_qualifier_code: nil)
      end
      let!(:specific_measure) do
        create(:measure, :with_measure_components, monetary_unit_code: 'GBP')
      end

      let(:params) { { filter: { has_ad_valorem: 'true' } } }

      before { do_request }

      it 'returns only measures with ad valorem components' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(ad_valorem_measure.measure_sid)
        expect(ids).not_to include(specific_measure.measure_sid)
      end
    end

    context 'when using as_of param' do
      let(:past_date) { 5.years.ago.to_date }
      let!(:expired_measure) do
        create(:measure,
               validity_start_date: past_date - 1.year,
               validity_end_date: past_date,
               measure_type_series_id: 'A')
      end
      let!(:current_measure) { create(:measure, measure_type_series_id: 'A') }

      before do
        get '/uk/api/measures/search',
            params: { as_of: past_date.iso8601, filter: { measure_type_series: %w[A] } },
            headers: request_headers(format: :json)
      end

      it 'returns measures valid at the specified date' do
        ids = json['data'].map { |m| m['id'].to_i }
        expect(ids).to include(expired_measure.measure_sid)
        expect(ids).not_to include(current_measure.measure_sid)
      end

      it 'includes the as_of date in meta' do
        expect(json.dig('meta', 'as_of')).to eq(past_date.iso8601)
      end
    end

    context 'when summary mode is enabled' do
      before do
        create(:measure, measure_type_series_id: 'A')
        create(:measure, measure_type_series_id: 'A')
        create(:measure, measure_type_series_id: 'C')
        get '/uk/api/measures/search',
            params: { summary: 'true' },
            headers: request_headers(format: :json)
      end

      it 'returns summary meta instead of data array' do
        expect(json).to have_key('meta')
        expect(json).not_to have_key('data')
      end

      it 'includes total_count and by_series breakdown' do
        expect(json.dig('meta', 'total_count')).to eq(3)
        expect(json.dig('meta', 'by_series', 'A')).to eq(2)
        expect(json.dig('meta', 'by_series', 'C')).to eq(1)
      end
    end
  end
end
