class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    ChangesTablePopulator.populate
    ChangesTablePopulator.cleanup_outdated

    if TariffChange.count.zero?
      TariffChangesService.populate_backlog
    else
      TariffChangesService.generate
    end

    DeltaReportService.generate
  end
end
