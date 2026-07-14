class XiCnReimportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(version)
    return unless TradeTariffBackend.xi?

    XiCnImporter::Reimporter.new.call(version:)
  end
end
