class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if TradeTariffBackend.reporting_enabled?
      Reporting::Commodities.generate
      Reporting::Basic.generate
      Reporting::SupplementaryUnits.generate
      Reporting::DeclarableDuties.generate
      Reporting::Prohibitions.generate
      Reporting::GeographicalAreaGroups.generate

      mail_differences if mail_differences?
    end
  end

  private

  def mail_differences
    ReportsMailer.differences(differences).deliver_now
  end

  def mail_differences?
    TradeTariffBackend.uk? && monday?
  end

  def differences
    Reporting::Differences.generate
  end

  def monday?
    Time.zone.now.monday?
  end
end
