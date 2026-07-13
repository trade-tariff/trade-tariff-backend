require 'rails_helper'
require_relative '../../../config/environments/production_environment_config'

RSpec.describe ProductionEnvironmentConfig do
  subject(:config) do
    ActiveSupport::OrderedOptions.new.tap do |c|
      c.action_controller = ActiveSupport::OrderedOptions.new
      c.action_mailer = ActiveSupport::OrderedOptions.new
      c.active_support = ActiveSupport::OrderedOptions.new
      c.public_file_server = ActiveSupport::OrderedOptions.new
      c.lograge = ActiveSupport::OrderedOptions.new
      c.i18n = ActiveSupport::OrderedOptions.new
      c.middleware = instance_double(ActionDispatch::MiddlewareStack)
    end
  end

  describe '.configure_runtime' do
    it 'configures production runtime defaults' do
      described_class.configure_runtime(config)

      expect(config.enable_reloading).to be(false)
      expect(config.eager_load).to be(true)
      expect(config.consider_all_requests_local).to be(false)
      expect(config.action_controller.perform_caching).to be(true)
      expect(config.public_file_server.enabled).to be(false)
    end
  end

  describe '.configure_ssl' do
    around do |example|
      originals = ENV.to_hash.slice('RAILS_FORCE_SSL', 'RAILS_ASSUME_SSL')
      example.run
    ensure
      %w[RAILS_FORCE_SSL RAILS_ASSUME_SSL].each do |key|
        if originals[key].nil?
          ENV.delete(key)
        else
          ENV[key] = originals[key]
        end
      end
    end

    it 'disables force_ssl and assume_ssl by default' do
      ENV.delete('RAILS_FORCE_SSL')
      ENV.delete('RAILS_ASSUME_SSL')

      described_class.configure_ssl(config)

      expect(config.force_ssl).to be(false)
      expect(config.assume_ssl).to be(false)
    end

    it 'enables force_ssl and assume_ssl when RAILS_FORCE_SSL is true' do
      ENV['RAILS_FORCE_SSL'] = 'true'
      ENV['RAILS_ASSUME_SSL'] = 'true'

      described_class.configure_ssl(config)

      expect(config.force_ssl).to be(true)
      expect(config.assume_ssl).to be(true)
    end

    it 'does not assume ssl when force_ssl is on but RAILS_ASSUME_SSL is false' do
      ENV['RAILS_FORCE_SSL'] = 'true'
      ENV['RAILS_ASSUME_SSL'] = 'false'

      described_class.configure_ssl(config)

      expect(config.force_ssl).to be(true)
      expect(config.assume_ssl).to be(false)
    end
  end

  describe '.truncate_lograge_exception_message' do
    subject(:truncate) { described_class.truncate_lograge_exception_message }

    it 'returns empty hash for blank messages' do
      expect(truncate.call(nil)).to eq({})
      expect(truncate.call('')).to eq({})
    end

    it 'keeps short messages untruncated' do
      expect(truncate.call('boom')).to eq(
        exception_message: 'boom',
        exception_message_truncated: false,
      )
    end

    it 'truncates long messages at 500 characters' do
      long = 'x' * 600
      result = truncate.call(long)

      expect(result[:exception_message]).to eq('x' * 500)
      expect(result[:exception_message_truncated]).to be(true)
    end
  end

  describe '.lograge_custom_options' do
    it 'merges request metadata and truncated exception message' do
      event = instance_double(
        ActiveSupport::Notifications::Event,
        payload: {
          request_id: 'req-1',
          auth_type: 'token',
          client_id: 'client',
          headers: { 'HTTP_ACCEPT' => 'application/json' },
          exception_object: StandardError.new('failure'),
          exception: %w[StandardError failure],
          params: {
            'controller' => 'healthcheck',
            'action' => 'index',
            'format' => 'json',
            'utf8' => '✓',
            'q' => 'tea',
          },
          user_agent: 'rspec',
        },
      )

      options = described_class.lograge_custom_options.call(event)

      expect(options).to include(
        request_id: 'req-1',
        auth_type: 'token',
        client_id: 'client',
        accept: 'application/json',
        exception_class: 'StandardError',
        exception_message: 'failure',
        exception_message_truncated: false,
        params: { 'q' => 'tea' },
        user_agent: 'rspec',
      )
    end
  end

  describe '.configure_cache' do
    around do |example|
      original = ENV['SERVICE']
      example.run
    ensure
      if original.nil?
        ENV.delete('SERVICE')
      else
        ENV['SERVICE'] = original
      end
    end

    it 'uses redis cache store with service namespace and thread pool' do
      allow(TradeTariffBackend).to receive_messages(
        redis_config: { url: 'redis://example:6379' },
        max_threads: 9,
      )
      ENV['SERVICE'] = 'xi'

      described_class.configure_cache(config)

      store, options = config.cache_store
      expect(store).to eq(:redis_cache_store)
      expect(options).to include(
        url: 'redis://example:6379',
        expires_in: 1.day,
        namespace: 'rails-cache-xi',
        pool: { size: 9 },
      )
    end

    it 'defaults namespace service to uk' do
      allow(TradeTariffBackend).to receive_messages(
        redis_config: { url: 'redis://example:6379' },
        max_threads: 5,
      )
      ENV.delete('SERVICE')

      described_class.configure_cache(config)

      _store, options = config.cache_store
      expect(options[:namespace]).to eq('rails-cache-uk')
    end
  end

  describe '.configure_mailer' do
    it 'disables mailer caching and uses ses_v2 with locale fallbacks' do
      allow(I18n).to receive(:default_locale).and_return(:en)

      described_class.configure_mailer(config)

      expect(config.action_mailer.perform_caching).to be(false)
      expect(config.action_mailer.delivery_method).to eq(:ses_v2)
      expect(config.i18n.fallbacks).to eq([:en])
    end
  end

  describe '.secure_credential_compare' do
    it 'returns true when the value matches the sidekiq credential' do
      allow(Rails.application).to receive(:credentials).and_return(
        ActiveSupport::InheritableOptions.new(
          sidekiq: ActiveSupport::InheritableOptions.new(username: 'user', password: 'secret'),
        ),
      )

      expect(described_class.secure_credential_compare('user', :username)).to be(true)
      expect(described_class.secure_credential_compare('wrong', :username)).to be(false)
    end
  end
end
