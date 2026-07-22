RSpec.describe Api::V2::ChangesByPeriodController do
  describe 'GET #index' do
    subject(:do_request) { get '/uk/api/changes_by_period', params:, headers: request_headers(format: :json) }

    let(:json) { JSON.parse(response.body) }

    context 'when from_date is missing' do
      let(:params) { { to_date: Time.zone.today.iso8601 } }

      before { do_request }

      it 'returns bad request' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when to_date is before from_date' do
      let(:params) { { from_date: Time.zone.today.iso8601, to_date: (Time.zone.today - 1.day).iso8601 } }

      before { do_request }

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with a valid date range' do
      let(:from) { 7.days.ago.to_date }
      let(:params) { { from_date: from.iso8601, to_date: Time.zone.today.iso8601 } }

      context 'when no changes exist in the range' do
        before { do_request }

        it 'is successful' do
          expect(response).to be_successful
        end

        it 'returns empty data' do
          expect(json['data']).to eq([])
        end

        it 'includes range and pagination in meta' do
          expect(json['meta']).to include(
            'from_date' => from.iso8601,
            'to_date' => Time.zone.today.iso8601,
          )
          expect(json.dig('meta', 'pagination')).to include(
            'total_count' => 0,
          )
        end
      end

      context 'when changes exist in the range' do
        let!(:change_in_range) { create(:change, change_date: from + 2.days) }

        before do
          create(:change, change_date: from - 1.day)
          do_request
        end

        it 'returns only in-range changes with the correct count' do
          ids = json['data'].map { |c| c['id'].to_i }
          expect(ids).to contain_exactly(change_in_range.id)
          expect(json.dig('meta', 'pagination', 'total_count')).to eq(1)
        end
      end

      context 'when paginating' do
        before do
          create_list(:change, 5, change_date: from + 1.day)
          get '/uk/api/changes_by_period',
              params: params.merge(per_page: 2, page: 1),
              headers: request_headers(format: :json)
        end

        it 'returns per_page results' do
          expect(json['data'].length).to eq(2)
        end

        it 'reports the full total_count' do
          expect(json.dig('meta', 'pagination', 'total_count')).to eq(5)
        end
      end

      context 'when to_date is omitted' do
        let(:params) { { from_date: from.iso8601 } }

        before { do_request }

        it 'defaults to_date to today and is successful' do
          expect(response).to be_successful
          expect(json.dig('meta', 'to_date')).to eq(Time.zone.today.iso8601)
        end
      end
    end
  end
end
