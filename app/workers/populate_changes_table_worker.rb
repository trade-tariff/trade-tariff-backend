class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    ChangesTablePopulator.populate
    ChangesTablePopulator.cleanup_outdated

    TariffChangesService.generate
    TariffChangesService.generate_report_for(Time.zone.today)
  end
end
