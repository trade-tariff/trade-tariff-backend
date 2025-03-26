class Appendix5aMailer < ApplicationMailer
  default to: TradeTariffBackend.cupid_team_to_emails

  def appendix5a_notify_message(new, changed, removed)
    mail subject: "[OTT has made updates from appendix 5a: #{new} new, #{changed} changed, #{removed} removed CDS guidance documents]",
         content_type: 'text/html',
         body: appendix5a_notify_body(new, changed, removed)
  end

  def appendix5a_notify_body(new, changed, removed)
    <<~HTML
      <html>
        <body>
          <p>Dear CUPID team,</p>
          <p>You are receiving this e-mail because the OTT has made the following number of changes from updates to the Appendix5a Documents:</p>
          <ul>
            <li>#{new} new</li>
            <li>#{changed} changed</li>
            <li>#{removed} removed</li>
          </ul>
          <p>If these numbers of updates are not expected, please contact <a href='mailto:#{TradeTariffBackend.support_email}'>#{TradeTariffBackend.support_email}</a>.</p>
        </body>
      </html>
    HTML
  end
end
