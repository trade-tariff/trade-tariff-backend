RSpec.describe Api::ApiController, type: :request do
  subject(:page_response) { make_request && response }

  let(:chapter) { create :chapter, :with_section }

  describe 'GET to #show' do
    let(:make_request) { get "/chapters/#{chapter.short_code}" }

    it { is_expected.to have_http_status :success }

    context 'cache headers' do
      before do
        allow(Rails.configuration.action_controller).to \
          receive(:perform_caching).and_return(true)
      end

      subject { page_response.headers.to_h }

      it { is_expected.to include 'ETag' }
      it { is_expected.to include 'Cache-Control' => /public/i }
      it { is_expected.to include 'Cache-Control' => /max-age=120/i }
    end
  end
end
