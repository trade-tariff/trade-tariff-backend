# frozen_string_literal: true

RSpec.describe TradeTariffBackend::ServiceTimeout do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(_env) { [200, {}, %w[OK]] } }

  around do |example|
    original_timeout = ENV['RACK_TIMEOUT_SERVICE_TIMEOUT']
    original_overrides = ENV['RACK_TIMEOUT_PATH_OVERRIDES']
    example.run
  ensure
    ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] = original_timeout
    ENV['RACK_TIMEOUT_PATH_OVERRIDES'] = original_overrides
  end

  before do
    allow(Timeout).to receive(:timeout).and_call_original
  end

  describe '#call' do
    context 'with default path overrides' do
      before do
        ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] = '50'
        ENV.delete('RACK_TIMEOUT_PATH_OVERRIDES')
      end

      it 'applies 100s timeout to /uk/internal/search' do
        middleware.call('PATH_INFO' => '/uk/internal/search')
        expect(Timeout).to have_received(:timeout).with(100)
      end

      it 'applies 100s timeout to /xi/internal/search' do
        middleware.call('PATH_INFO' => '/xi/internal/search')
        expect(Timeout).to have_received(:timeout).with(100)
      end

      it 'applies default timeout to internal search suggestions' do
        middleware.call('PATH_INFO' => '/uk/internal/search_suggestions')
        expect(Timeout).to have_received(:timeout).with(50)
      end

      it 'applies default timeout to public search' do
        middleware.call('PATH_INFO' => '/uk/api/search')
        expect(Timeout).to have_received(:timeout).with(50)
      end
    end

    context 'with custom path overrides' do
      before do
        ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] = '50'
        ENV['RACK_TIMEOUT_PATH_OVERRIDES'] = '/api/slow:60'
      end

      it 'uses the custom override' do
        middleware.call('PATH_INFO' => '/api/slow')
        expect(Timeout).to have_received(:timeout).with(60)
      end

      it 'uses the default timeout for non-matching paths' do
        middleware.call('PATH_INFO' => '/uk/internal/search')
        expect(Timeout).to have_received(:timeout).with(50)
      end
    end

    context 'with empty RACK_TIMEOUT_PATH_OVERRIDES' do
      before do
        ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] = '40'
        ENV['RACK_TIMEOUT_PATH_OVERRIDES'] = ''
      end

      it 'uses the default timeout for all paths' do
        middleware.call('PATH_INFO' => '/uk/internal/search')
        expect(Timeout).to have_received(:timeout).with(40)
      end
    end

    it 'calls the downstream app' do
      status, = middleware.call('PATH_INFO' => '/')
      expect(status).to eq(200)
    end
  end
end
