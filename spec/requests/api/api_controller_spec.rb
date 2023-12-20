RSpec.describe Api::ApiController, type: :request do
  subject(:page_response) { make_request && response }

  let(:chapter) { create :chapter, :with_section }

  describe 'GET to #show' do
    let(:make_request) { get "/chapters/#{chapter.short_code}" }

    it { is_expected.to have_http_status :success }

    describe 'cache headers' do
      before do
        allow(Rails.configuration.action_controller).to \
          receive(:perform_caching).and_return(true)
      end

      subject { page_response.headers.to_h }

      it { is_expected.to include 'ETag' }
      it { is_expected.to include 'Cache-Control' => /public/i }
      it { is_expected.to include 'Cache-Control' => /max-age=120/i }

      context 'when tariff_updates present' do
        before { create :base_update, :applied_yesterday }

        let :earlier_request do
          get("/chapters/#{chapter.short_code}") && response
        end

        it { is_expected.to include 'ETag' => earlier_request.headers['ETag'] }
      end

      context 'when latest tariff_update changes' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          create :base_update, :applied_today
        end

        let(:earlier_request) { get("/chapters/#{chapter.short_code}") && response }

        it { is_expected.not_to include 'ETag' => earlier_request.headers['ETag'] }
      end
    end
  end
end
