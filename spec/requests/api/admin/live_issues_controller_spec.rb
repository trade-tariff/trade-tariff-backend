RSpec.describe Api::Admin::LiveIssuesController, :admin do
  let(:json_response) { JSON.parse(response.body) }
  let(:live_issue) { create(:live_issue) }

  describe 'GET #index' do
    it 'returns a list of live issues' do
      live_issue

      authenticated_get api_admin_live_issues_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('data')
      expect(json_response['data'].size).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns a single live issue' do
      live_issue

      authenticated_get api_admin_live_issue_path(live_issue.id, format: :json)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('data')
      expect(json_response['data']['attributes'].size).to eq(8)
    end

    it 'returns 404 if the live issue does not exist' do
      authenticated_get api_admin_live_issue_path(0, format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:live_issue_data) do
      {
        title: 'Live Issue',
        description: 'Description',
        suggested_action: 'Suggested Action',
        status: 'Active',
        date_discovered: Time.zone.today,
        commodities: '0101010101 0101010201',
      }
    end

    context 'when the live issue is valid' do
      it 'creates a new live issue' do
        authenticated_post api_admin_live_issues_path(format: :json), params: { data: { type: 'live_issues', attributes: live_issue_data } }

        expect(response).to have_http_status(:created)
        expect(json_response).to include('data')
        expect(json_response['data']['attributes'].size).to eq(8)
      end
    end

    context 'when the live issue is invalid' do
      it 'returns 422 if the live issue is invalid' do
        authenticated_post api_admin_live_issues_path(format: :json), params: { data: { type: 'live_issues', attributes: live_issue_data.merge(title: nil) } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors'].first['detail']).to include('Title is not present')
      end
    end
  end

  describe 'PATCH #update' do
    before do
      live_issue
    end

    let(:live_issue_data) do
      {
        title: 'Live Issue',
        description: 'Description',
        suggested_action: 'Suggested Action',
        status: 'Resolved',
        date_discovered: Time.zone.today,
        commodities: '0101010103 0101010104',
      }
    end

    context 'when the live issue is valid' do
      it 'updates the live issue' do
        authenticated_patch api_admin_live_issue_path(live_issue.id, format: :json), params: { data: { type: 'live_issues', attributes: live_issue_data } }

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('data')
        expect(json_response['data']['attributes'].size).to eq(8)
        expect(json_response['data']['attributes']['status']).to eq('Resolved')
      end
    end

    context 'when the live issue is invalid' do
      it 'returns 422 if the live issue is invalid' do
        authenticated_patch api_admin_live_issue_path(live_issue.id, format: :json), params: { data: { type: 'live_issues', attributes: live_issue_data.merge(title: nil) } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors'].first['detail']).to include('Title is not present')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when the live issue is valid' do
      it 'deletes the live issue' do
        live_issue

        authenticated_delete api_admin_live_issue_path(live_issue.id, format: :json)

        expect(response).to have_http_status(:no_content)
      end
    end

    it 'returns 404 if the live issue does not exist' do
      authenticated_delete api_admin_live_issue_path(0, format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
