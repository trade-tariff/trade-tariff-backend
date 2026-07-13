require 'rails_helper'
require_relative '../../../config/environments/development_environment_config'

RSpec.describe DevelopmentEnvironmentConfig do
  subject(:config) { ActiveSupport::OrderedOptions.new.tap { |c| c.action_controller = ActiveSupport::OrderedOptions.new } }

  before do
    config.action_mailer = ActiveSupport::OrderedOptions.new
    config.active_support = ActiveSupport::OrderedOptions.new
    config.active_job = ActiveSupport::OrderedOptions.new
    config.action_dispatch = ActiveSupport::OrderedOptions.new
    config.public_file_server = ActiveSupport::OrderedOptions.new
  end

  describe '.configure_reloading' do
    it 'enables reloading and disables eager load' do
      described_class.configure_reloading(config)

      expect(config.enable_reloading).to be(true)
      expect(config.eager_load).to be(false)
    end
  end

  describe '.configure_error_reporting' do
    it 'shows full errors and enables server timing' do
      described_class.configure_error_reporting(config)

      expect(config.action_dispatch.show_exceptions).to eq(:all)
      expect(config.consider_all_requests_local).to be(true)
      expect(config.server_timing).to be(true)
    end
  end

  describe '.configure_caching' do
    it 'uses null store when caching-dev toggle is absent' do
      allow(Rails.root).to receive(:join).with('tmp/caching-dev.txt').and_return(
        instance_double(Pathname, exist?: false),
      )

      described_class.configure_caching(config)

      expect(config.action_controller.perform_caching).to be(false)
      expect(config.cache_store).to eq(:null_store)
    end

    it 'enables memory store when caching-dev toggle is present' do
      allow(Rails.root).to receive(:join).with('tmp/caching-dev.txt').and_return(
        instance_double(Pathname, exist?: true),
      )

      described_class.configure_caching(config)

      expect(config.action_controller.perform_caching).to be(true)
      expect(config.action_controller.enable_fragment_cache_logging).to be(true)
      expect(config.cache_store).to eq(:memory_store)
      expect(config.public_file_server.headers['Cache-Control']).to include('public, max-age=')
    end
  end

  describe '.configure_mailer' do
    around do |example|
      original = ENV['DEFAULT_MAIL_HOST']
      example.run
    ensure
      if original.nil?
        ENV.delete('DEFAULT_MAIL_HOST')
      else
        ENV['DEFAULT_MAIL_HOST'] = original
      end
    end

    it 'uses letter_opener and default docker host' do
      ENV.delete('DEFAULT_MAIL_HOST')

      described_class.configure_mailer(config)

      expect(config.action_mailer.raise_delivery_errors).to be(false)
      expect(config.action_mailer.perform_caching).to be(false)
      expect(config.action_mailer.delivery_method).to eq(:letter_opener)
      expect(config.action_mailer.default_url_options).to eq(
        host: 'host.docker.internal',
        port: 3000,
      )
    end

    it 'respects DEFAULT_MAIL_HOST' do
      ENV['DEFAULT_MAIL_HOST'] = 'mail.test'

      described_class.configure_mailer(config)

      expect(config.action_mailer.default_url_options[:host]).to eq('mail.test')
    end
  end

  describe '.configure_deprecations' do
    it 'logs deprecations and raises on disallowed ones' do
      described_class.configure_deprecations(config)

      expect(config.active_support.deprecation).to eq(:log)
      expect(config.active_support.disallowed_deprecation).to eq(:raise)
      expect(config.active_support.disallowed_deprecation_warnings).to eq([])
    end
  end
end
