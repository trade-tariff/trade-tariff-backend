RSpec.describe Api::Admin::HeadingsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:heading) { create(:heading, :non_declarable, :with_chapter).reload }

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_heading_path(heading_id, format: :json)
    end

    context 'with known heading' do
      let(:heading_id) { heading.short_code }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'with unknown heading' do
      let(:heading_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
