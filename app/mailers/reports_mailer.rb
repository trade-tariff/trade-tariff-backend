class ReportsMailer < ApplicationMailer
  default to: TradeTariffBackend.differences_report_to_emails, bcc: TradeTariffBackend.support_email

  def differences(report)
    @report = report
    @sections = report.sections
    @report_date = report.as_of.to_date.to_fs(:govuk)

    attachments["differences_#{report.as_of}.xlsx"] = report.workbook.read_string

    mail subject: "[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{report.as_of}"
  end

  def commodity_watchlist(date, workbook)
    attachments["commodity_watchlist_#{date}.xlsx"] = workbook.read_string

    mail to: TradeTariffBackend.delta_report_to_emails, bcc: nil, subject: "[HMRC Online Trade Tariff] - UK tariff changes report #{date}"
  end
end
