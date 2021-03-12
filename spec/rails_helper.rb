ENV['RAILS_ENV'] ||= 'test'

require 'spec_helper'

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

require 'simplecov'

SimpleCov.start 'rails'

require File.expand_path('../config/environment', __dir__)

require 'rspec/rails'
require 'json_expressions/rspec'
require 'fakefs/spec_helpers'
require 'sidekiq/testing'
require 'elasticsearch/extensions/test/cluster'

require Rails.root.join('spec/support/tariff_validation_matcher.rb')
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# require models and serializers
require 'clearable'
Dir[Rails.root.join('app/models/*.rb')].sort.each { |f| require f }
# Dir[Rails.root.join('app/models/concerns/*rb')].each { |f| require concern }
Dir[Rails.root.join('app/serializers/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.raise_errors_for_deprecations!
  config.infer_spec_type_from_file_location!
  config.infer_base_class_for_anonymous_controllers = false
  config.alias_it_should_behave_like_to :it_results_in, 'it results in'
  config.alias_it_should_behave_like_to :it_is_associated, 'it is associated'
  config.include RSpec::Rails::RequestExampleGroup, type: :request, file_path: /spec\/api/
  config.include ControllerSpecHelper, type: :controller
  config.include SynchronizerHelper
  config.include LoggerHelper
  config.include RescueHelper
  config.include ChiefDataHelper
  config.include CodesMappingHelper
  config.include ActiveSupport::Testing::TimeHelpers

  redis = Redis.new(db: 15)
  RedisLockDb.redis = redis

  config.before(:suite) do
    TradeTariffBackend.redis.flushdb
    redis.flushdb
  end

  config.after(:suite) do
    TradeTariffBackend.redis.flushdb
    redis.flushdb
  end

  config.before do
    stub_codes_mapping_data
    Rails.cache.clear
    Sidekiq::Worker.clear_all

    TradeTariffBackend.clearable_models.map(&:clear_association_cache)
  end
end
