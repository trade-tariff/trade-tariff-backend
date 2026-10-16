class ReportsMailer < ApplicationMailer
  XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
  default to: -> { Array(TradeTariffBackend.differences_report_to_emails) },
          bcc: -> { Array(TradeTariffBackend.support_email) }

  def differences(report)
    @report = report
    @sections = report.sections
    @report_date = report.as_of.to_date.to_fs(:govuk)

    attachments["differences_#{report.as_of}.xlsx"] = {
      mime_type: XLSX_CONTENT_TYPE,
      encoding: 'base64',
      content: Base64.strict_encode64(report.workbook_data),
    }

    mail subject: "[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{report.as_of}"
  end

  def search_reference_changes(result)
    recipients = TradeTariffBackend.search_references_report_to_emails
    return if recipients.blank?

    @result = result
    @service_name = TradeTariffBackend.uk? ? 'UK' : 'Northern Ireland'

    attachments[result.filename] = {
      mime_type: 'text/csv',
      content: result.csv_data,
    }

    mail to: recipients,
         subject: "[HMRC Online Trade Tariff Support] #{@service_name} tariff - search reference changes #{result.period_label}"
  end
end
