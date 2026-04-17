class ImportCustomsTariffDocumentWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    results = ImportCustomsTariffDocumentService.new.call
    imported = results.select { |r| r.status == :imported }.map(&:version)
    failed   = results.select { |r| r.status == :failed }

    if imported.any?
      SlackNotifierService.call("Customs Tariff documents imported: versions #{imported.join(', ')} — pending approval")
    end

    failed.each do |r|
      SlackNotifierService.call("Customs Tariff document import failed: #{r.error}")
    end
  end
end
