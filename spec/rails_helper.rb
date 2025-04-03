ENV['RAILS_ENV'] ||= 'test'

require 'spec_helper'

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

require File.expand_path('../config/environment', __dir__)

require 'rspec/rails'
require 'json_expressions/rspec'
require 'sidekiq/testing'

Rails.application.load_tasks

Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

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
  config.include RescueHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.include_context 'with fake global rules of origin data'

  config.around do |example|
    # Workers are known to operate outside of TimeMachine so make them
    # responsible for setting the date
    if example.metadata[:type].in? %i[worker]
      TimeMachine.no_time_machine { example.run }
    else
      TimeMachine.now { example.run }
    end
  end

  config.before(:all) do
    FileUtils.rm_rf('tmp/data/cds')
    FileUtils.mkpath('tmp/data/cds')
    FileUtils.cp_r('spec/fixtures/cds_samples/.', 'tmp/data/cds')
  end

  config.before(:suite) do
    # Materialized Views need populating after a schema load before concurrent
    # refresh can be used. Doing a blocking refresh to ensure the View is in a
    # usable state. This is very fast since there is no data
    GoodsNomenclatures::TreeNode.refresh!(concurrently: false)

    TradeTariffBackend.redis.flushdb

    MeasureTypeExclusion.load_from_file \
      Rails.root.join('spec/fixtures/measure_type_exclusions.csv')
  end

  config.after(:suite) do
    TradeTariffBackend.redis.flushdb
  end

  config.before do
    Rails.cache.clear
    Sidekiq::Worker.clear_all

    # things like nomenclature item id's risk wrapping otherwise
    FactoryBot.rewind_sequences
  end

  config.after { travel_back }

  config.include V2Api.routes.url_helpers, type: :request

  config.verbose_retry = true
  config.display_try_failure_messages = true
  config.around { |ex| ex.run_with_retry retry: 3 }
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

def strong_params(wimpy_params)
  ActionController::Parameters.new(wimpy_params).permit!
end
