class CustomsTariffReimportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(version)
    return unless TradeTariffBackend.uk?

    CustomsTariffImporter::Reimporter.new.call(version:)
  end
end
