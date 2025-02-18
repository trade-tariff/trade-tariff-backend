require 'spec_helper'

RSpec.describe 'Maintenance mode', type: :request do
  subject { response }

  describe 'making an API request whilst maintenance mode is enabled' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('MAINTENANCE').and_return 'true'
    end

    context 'without bypass enabled' do
      before { get '/api/v2/sections.json' }

      it { is_expected.to have_http_status :service_unavailable }
    end

    context 'with bypass enabled' do
      before do
        allow(ENV).to receive(:[]).with('MAINTENANCE_BYPASS').and_return 'bypass'
      end

      context 'without bypass param' do
        before { get '/api/v2/sections.json' }

        it { is_expected.to have_http_status :service_unavailable }
      end

      context 'with wrong bypass param' do
        before { get '/api/v2/sections.json?maintenance_bypass=something' }

        it { is_expected.to have_http_status :service_unavailable }
      end

      context 'with correct bypass param' do
        before do
          get '/api/v2/sections.json?maintenance_bypass=bypass'
        end

        it { is_expected.to have_http_status :success }
      end
    end
  end
end
