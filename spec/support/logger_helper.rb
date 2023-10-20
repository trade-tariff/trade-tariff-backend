require 'active_support/log_subscriber/test_helper'

module LoggerHelper
  include ActiveSupport::LogSubscriber::TestHelper

  def tariff_importer_logger
    setup # Setup LogSubscriber::TestHelper
    TariffImporter::Logger.attach_to :tariff_importer
    yield
    teardown
  end
end
