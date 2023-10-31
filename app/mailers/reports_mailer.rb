class ReportsMailer < ApplicationMailer
  default to: TradeTariffBackend.differences_report_to_emails, bcc: TradeTariffBackend.support_email

  def differences(report)
    @sections = report.sections
    @report_date = report.as_of.to_date.to_fs(:govuk)

    attachments["differences_#{report.as_of}.xlsx"] = report.package.to_stream.read
    attachments["uk_commodities_#{report.as_of}.csv"] = Reporting::Commodities.get_uk_today
    attachments["eu_commodities_#{report.as_of}.csv"] = Reporting::Commodities.get_xi_today
    attachments["uk_supplementary_units_#{report.as_of}.csv"] = Reporting::SupplementaryUnits.get_uk_today
    attachments["eu_supplementary_units_#{report.as_of}.csv"] = Reporting::SupplementaryUnits.get_xi_today

    mail subject: "[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{report.as_of}"
  end
end
