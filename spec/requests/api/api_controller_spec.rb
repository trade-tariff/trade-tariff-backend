RSpec.describe Api::ApiController, type: :request do
  subject(:page_response) { get(testpath) && response }

  let(:chapter) { create :chapter, :with_section }

  describe 'GET to #show' do
    let(:testpath) { "/chapters/#{chapter.short_code}" }

    it { is_expected.to have_http_status :success }

    describe 'cache headers' do
      subject { page_response.headers.to_h }

      before do
        allow(Rails.configuration.action_controller).to \
          receive(:perform_caching).and_return(true)
      end

      let(:earlier_request) { get(testpath) && response }

      it { is_expected.to include 'ETag' }
      it { is_expected.to include 'Cache-Control' => /public/i }
      it { is_expected.to include 'Cache-Control' => /max-age=120/i }

      context 'when tariff_updates present' do
        before { create :base_update, :applied_yesterday }

        it { is_expected.to include 'ETag' => earlier_request.headers['ETag'] }
      end

      context 'when latest tariff_update changes' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          create :base_update, :applied_today
        end

        it { is_expected.not_to include 'ETag' => earlier_request.headers['ETag'] }
      end

      context 'when current day changes and as_of not specified' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          travel 1.day
        end

        it { is_expected.not_to include 'ETag' => earlier_request.headers['ETag'] }
      end

      context 'when current day changes and as_of is specified' do
        before do
          create :base_update, :applied_yesterday
          earlier_request
          travel 1.day
        end

        let :testpath do
          "/chapters/#{chapter.short_code}?as_of=#{Time.zone.today.to_fs :db}"
        end

        it { is_expected.to include 'ETag' => earlier_request.headers['ETag'] }
      end
    end
  end
end
