class ActionLogMailer < ApplicationMailer
  default from: TradeTariffBackend.from_email

  def daily_report(csv_data, date)
    recipients = Array(TradeTariffBackend.myott_report_email)
    return if recipients.blank?

    @date = date

    attachments["action_logs_#{date}.csv"] = {
      mime_type: 'text/csv',
      content: csv_data,
    }

    mail(
      to: recipients,
      subject: "[HMRC Online Trade Tariff] User Action Logs Report #{@date}",
    )
  end
end
