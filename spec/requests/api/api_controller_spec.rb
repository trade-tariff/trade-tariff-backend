RSpec.describe Api::ApiController, type: :request do
  subject(:page_response) { get(testpath, headers:) && response }

  let(:chapter) { create :chapter, :with_section }

  let(:headers) { { 'HTTP_USER_AGENT' => 'TradeTariffFrontend/2ebf4292' } }

  describe 'GET to #show' do
    let(:testpath) { "/api/v2/chapters/#{chapter.short_code}" }

    it { is_expected.to have_http_status :success }

    describe 'cache headers' do
      subject { page_response.headers.to_h }

      before do
        allow(Rails.configuration.action_controller).to \
          receive(:perform_caching).and_return(true)
      end

      let(:earlier_request) { get(testpath, headers:) && response }

      it { is_expected.to include 'etag' }
      it { is_expected.to include 'cache-control' => /public/i }
      it { is_expected.to include 'cache-control' => /max-age=120/i }

      context 'when tariff_updates present' do
        before { create :base_update, :applied_yesterday }

        it { is_expected.to include 'etag' => earlier_request.headers['ETag'] }
      end

      context 'when latest tariff_update changes' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          create :base_update, :applied_today
        end

        it { is_expected.not_to include 'etag' => earlier_request.headers['ETag'] }
      end

      context 'when current day changes and as_of not specified' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          travel 1.day
        end

        it { is_expected.not_to include 'etag' => earlier_request.headers['ETag'] }
      end

      context 'when current day changes and as_of is specified' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          travel 1.day
        end

        let :testpath do
          "/api/v2/chapters/#{chapter.short_code}?as_of=#{Time.zone.today.to_fs :db}"
        end

        it { is_expected.to include 'etag' => earlier_request.headers['ETag'] }
      end

      context 'when request originates not from the frontend' do
        subject { response.headers.to_h }

        before { get testpath, headers: }

        let(:testpath) { "/api/v2/chapters/#{chapter.short_code}" }
        let(:headers) { { 'HTTP_USER_AGENT' => 'curl/7.64.1' } }

        it { is_expected.to have_key('etag') }
        it { is_expected.not_to have_key('cache-control') }
      end
    end
  end
end
