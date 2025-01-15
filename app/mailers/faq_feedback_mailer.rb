class FaqFeedbackMailer < ApplicationMailer
  default to: TradeTariffBackend.support_email

  def faq_feedback_message
    mail subject: "[HMRC Online Trade Tariff Support] UK tariff - Green Lanes FAQ Feedback Report - #{TradeTariffBackend.service == 'uk' ? 'UK' : 'Northern Ireland'}",
         content_type: 'text/html',
         body: faq_feedback_statistics_body(GreenLanes::FaqFeedback.statistics)
  end

  def faq_feedback_statistics_body(results)
    report_html = <<~HTML
      <html>
      <body>
        <h2>Green Lanes FAQ Feedback Report for #{TradeTariffBackend.service == 'uk' ? 'UK' : 'Northern Ireland'}</h2>
        <p>A summary of FAQ Feedback Categories and Questions and their usefulness:</p>
        <table border="1" cellspacing="0" cellpadding="5">
          <thead>
            <tr>
              <th>Category ID</th>
              <th>Question ID</th>
              <th>Useful Count</th>
              <th>Not Useful Count</th>
            </tr>
          </thead>
          <tbody>
    HTML

    results.each do |row|
      report_html += <<~HTML
        <tr>
          <td>#{row[:category_id]}</td>
          <td>#{row[:question_id]}</td>
          <td>#{row[:useful_count]}</td>
          <td>#{row[:not_useful_count]}</td>
        </tr>
      HTML
    end

    report_html += <<~HTML
          </tbody>
        </table>
      </body>
      </html>
    HTML

    report_html
  end
end
