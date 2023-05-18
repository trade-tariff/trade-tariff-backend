class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if TradeTariffBackend.reporting_enabled?
      Reporting::Basic.generate
      Reporting::DeclarableDuties.generate
    end
  end
end
