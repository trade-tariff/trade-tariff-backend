class ReportsMailer < ApplicationMailer
  default to: TradeTariffBackend.differences_report_to_emails, bcc: TradeTariffBackend.support_email

  def differences(report)
    @report = report
    @sections = report.sections
    @report_date = report.as_of.to_date.to_fs(:govuk)

    attachments["differences_#{report.as_of}.xlsx"] = report.package.to_stream.read

    mail subject: "[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{report.as_of}"
  end

  def delta(report)
    attachments["commodity_watchlist_#{report[:dates]}.xlsx"] = report[:package].to_stream.read

    mail to: TradeTariffBackend.delta_report_to_emails, bcc: nil, subject: "[HMRC Online Trade Tariff] - UK tariff changes report #{report[:dates]}"
  end

  def commodity_watchlist(date, package)
    attachments["commodity_watchlist_#{date}.xlsx"] = package.to_stream.read

    mail to: TradeTariffBackend.delta_report_to_emails, bcc: nil, subject: "[HMRC Online Trade Tariff] - UK tariff changes report #{date}"
  end
end
