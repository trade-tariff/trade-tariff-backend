class XiCnReimportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  def perform(version)
    return unless TradeTariffBackend.xi?

    XiCnImporter::Reimporter.new.call(version:)
  end
end
