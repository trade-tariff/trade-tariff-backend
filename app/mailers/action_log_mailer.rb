class ActionLogMailer < ApplicationMailer
  default from: TradeTariffBackend.from_email

  def daily_report(csv_data, date)
    return if TradeTariffBackend.myott_report_email.blank?

    @date = date

    attachments["action_logs_#{date}.csv"] = {
      mime_type: 'text/csv',
      content: csv_data,
    }

    mail(
      to: TradeTariffBackend.myott_report_email,
      subject: "[HMRC Online Trade Tariff] User Action Logs Report #{@date}",
    )
  end
end
