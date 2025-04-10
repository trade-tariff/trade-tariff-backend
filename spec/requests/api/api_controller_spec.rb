RSpec.describe Api::ApiController, type: :request do
  subject(:page_response) { get("/api/v2/chapters/#{chapter.short_code}") && response }

  let(:chapter) { create :chapter, :with_section }

  describe 'GET to #show' do
    describe 'cache headers' do
      subject { page_response.headers.to_h }

      before do
        allow(Rails.configuration.action_controller).to \
          receive(:perform_caching).and_return(true)
      end

      it { is_expected.to have_key 'etag' }
      it { is_expected.not_to have_key 'cache-control' }
    end
  end
end
