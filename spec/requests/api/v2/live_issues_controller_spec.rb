RSpec.describe Api::V2::LiveIssuesController do
  let(:json_response) { JSON.parse(response.body) }
  let(:active_live_issue) { create :live_issue }
  let(:resolved_live_issue) { create :live_issue, status: 'Resolved', date_resolved: Time.zone.today }

  describe 'GET #index' do
    context 'when no filter is provided' do
      it 'returns all live issues' do
        active_live_issue
        resolved_live_issue

        get api_live_issues_path(format: :json), params: {}

        expect(response).to have_http_status(:success)
        expect(json_response).to include('data')
        expect(json_response['data'].size).to eq(2)
      end
    end

    context 'when filter is provided' do
      it 'returns only active live issues' do
        active_live_issue
        resolved_live_issue

        get api_live_issues_path(format: :json), params: { filter: { status: 'Active' } }

        expect(response).to have_http_status(:success)
        expect(json_response).to include('data')
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'][0]['attributes']['status']).to eq('Active')
      end

      it 'returns only resolved live issues' do
        active_live_issue
        resolved_live_issue

        get api_live_issues_path(format: :json), params: { filter: { status: 'Resolved' } }

        expect(response).to have_http_status(:success)
        expect(json_response).to include('data')
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'][0]['attributes']['status']).to eq('Resolved')
      end
    end

    context 'when error is provided' do
      before do
        allow(Api::V2::LiveIssueSerializer).to receive(:new).and_raise(StandardError.new('Serialization failed'))
      end

      it 'returns 400 if serialization fails' do
        get api_live_issues_path(format: :json)
        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors'].first['detail']).to include('Bad request')
      end
    end
  end
end
