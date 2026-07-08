module TradeTariffBackend
  module Config
    module Email
      def from_email
        ENV.fetch('TARIFF_FROM_EMAIL')
      end

      def admin_email
        ENV.fetch('TARIFF_SYNC_EMAIL')
      end

      def support_email
        ENV['TARIFF_SUPPORT_EMAIL']
      end

      def management_email
        ENV['TARIFF_MANAGEMENT_EMAIL']
      end

      def differences_report_to_emails
        ENV['DIFFERENCES_TO_EMAILS']
      end

      def cds_updates_send_email
        ENV.fetch('CDS_UPDATES_SEND_MAIL', 'false').to_s == 'true'
      end

      def cds_updates_to_email
        ENV.fetch('CDS_UPDATES_TO_EMAILS')
      end

      def cds_updates_cc_email
        ENV.fetch('CDS_UPDATES_CC_EMAILS', '')
      end

      def cupid_team_to_emails
        raw = ENV['CUPID_TEAM_TO_EMAILS']
        return [] if raw.blank?

        parse_email_list(raw)
      end

      def myott_report_email
        ENV['MYOTT_REPORT_EMAIL']
      end

    private

      def parse_email_list(raw)
        JSON.parse(raw).values.map(&:strip).reject(&:empty?)
      rescue JSON::ParserError
        raw.split(',').map(&:strip).reject(&:empty?)
      end
    end
  end
end
