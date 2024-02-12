class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform(trigger_differences_report = true)
    Reporting::Commodities.generate
    Reporting::Basic.generate
    Reporting::SupplementaryUnits.generate
    Reporting::DeclarableDuties.generate
    Reporting::Prohibitions.generate
    Reporting::GeographicalAreaGroups.generate

    schedule_differences_generation if trigger_differences_report
  end

  private

  def generate_differences?
    TradeTariffBackend.uk? && monday?
  end

  def schedule_differences_generation
    # Delays to ensure both XI and UK Report Workers have completed before
    # DifferencesReportWorker executes
    DifferencesReportWorker.perform_in(30.minutes) if generate_differences?
  end

  def monday?
    Time.zone.now.monday?
  end
end
