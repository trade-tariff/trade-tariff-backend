require 'active_support/log_subscriber/test_helper'

module LoggerHelper
  include ActiveSupport::LogSubscriber::TestHelper

  def tariff_importer_logger
    setup # Setup LogSubscriber::TestHelper
    TariffImporter::Logger.attach_to :tariff_importer
    yield
    teardown
  end

  def tariff_synchronizer_logger_listener
    setup # Setup LogSubscriber::TestHelper
    TariffSynchronizer::Logger.attach_to :tariff_synchronizer
  end
end
