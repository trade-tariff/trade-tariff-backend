class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if TradeTariffBackend.reporting_enabled?
      Reporting::Commodities.generate
      Reporting::Basic.generate
      Reporting::DeclarableDuties.generate
      Reporting::Prohibitions.generate
      Reporting::GeographicalAreaGroups.generate
    end
  end
end
