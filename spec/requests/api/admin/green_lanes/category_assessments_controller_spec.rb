RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentsController do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }
  let(:category) { create :category_assessment }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_category_assessments_path(format: :json)
    end

    context 'with some category assessments' do
      before do
        category
      end
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response).to include('meta') }
    end

    context 'without any category assessments' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end
end
