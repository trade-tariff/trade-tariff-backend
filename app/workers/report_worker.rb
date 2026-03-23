class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  REPORTS = [
    Reporting::Commodities,
    Reporting::Basic,
    Reporting::SupplementaryUnits,
    Reporting::DeclarableDuties,
    Reporting::Prohibitions,
    Reporting::GeographicalAreaGroups,
    Reporting::CategoryAssessments,
  ].freeze

  def perform(trigger_differences_report = true)
    return if Rails.env.development?

    failures = []

    REPORTS.each do |report|
      report.generate
    rescue StandardError => e
      failures << { report: report.name, error: e }
      Rails.logger.error("ReportWorker: #{report.name} failed: #{e.class} - #{e.message}")
    end

    schedule_differences_generation if trigger_differences_report

    raise failures.first[:error] if failures.any?
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
