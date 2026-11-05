class CustomsTariffReimportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  def perform(version)
    return unless TradeTariffBackend.uk?

    CustomsTariffImporter::Reimporter.new.call(version:)
  end
end
