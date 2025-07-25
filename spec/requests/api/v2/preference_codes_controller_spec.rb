RSpec.describe Api::V2::PreferenceCodesController, :v2 do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:make_request) { api_get api_preference_codes_path }

    it_behaves_like 'a successful jsonapi response'
  end

  describe 'GET #show' do
    context 'when it finds a preference_code' do
      subject(:rendered) { make_request && response }

      let(:preference_code) { PreferenceCode['100'] }

      let(:make_request) { api_get api_preference_code_path(preference_code.code) }

      it_behaves_like 'a successful jsonapi response'

      it { is_expected.to have_http_status :success }
    end

    context 'when preference code is not found' do
      subject(:rendered) { make_request && response }

      let :make_request do
        get api_preference_code_path('foo')
      end

      it { is_expected.to have_http_status :not_found }
    end
  end
end
