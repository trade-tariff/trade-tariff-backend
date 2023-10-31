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

      mail_differences if TradeTariffBackend.uk?
    end
  end

  private

  def mail_differences
    ReportsMailer.differences(differences).deliver_now
  end

  def differences
    @differences ||= Reporting::Differences.generate
  end
end
