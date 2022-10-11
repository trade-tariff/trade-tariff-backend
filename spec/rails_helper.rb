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

Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# require models and serializers
require 'clearable'

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.file_fixture_path = 'spec/fixtures'
  config.raise_errors_for_deprecations!
  config.infer_spec_type_from_file_location!
  config.infer_base_class_for_anonymous_controllers = false
  config.alias_it_should_behave_like_to :it_results_in, 'it results in'
  config.alias_it_should_behave_like_to :it_is_associated, 'it is associated'
  config.include RSpec::Rails::RequestExampleGroup, type: :request, file_path: /spec\/api/
  config.include ControllerSpecHelper, type: :controller
  config.include RequestSpecHelper, type: :request
  config.include SynchronizerHelper
  config.include LoggerHelper
  config.include RescueHelper
  config.include CodesMappingHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.include_context 'with fake global rules of origin data'

  config.before(:suite) do
    TradeTariffBackend.redis.flushdb

    MeasureTypeExclusion.load_from_file \
      Rails.root.join('spec/fixtures/measure_type_exclusions.csv')
  end

  config.after(:suite) do
    TradeTariffBackend.redis.flushdb
  end

  config.before do
    stub_codes_mapping_data

    Rails.cache.clear
    Sidekiq::Worker.clear_all

    TradeTariffBackend.clearable_models.map(&:clear_association_cache)
  end
end

def silence
  # Store the original stderr and stdout in order to restore them later
  @original_stderr = $stderr
  @original_stdout = $stdout

  # Redirect stderr and stdout
  $stderr = $stdout = StringIO.new

  yield

  $stderr = @original_stderr
  $stdout = @original_stdout
  @original_stderr = nil
  @original_stdout = nil
end
