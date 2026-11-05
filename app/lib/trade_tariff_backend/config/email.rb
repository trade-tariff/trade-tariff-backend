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

      def feedback_email
        ENV['TARIFF_FEEDBACK_EMAIL']
      end

      def differences_report_to_emails
        distribution_list_emails('dl-differences-report') || ENV['DIFFERENCES_TO_EMAILS']
      end

      def cds_updates_send_email
        ENV.fetch('CDS_UPDATES_SEND_MAIL', 'false').to_s == 'true'
      end

      # Comma-separated, as the mailer splits it.
      def cds_updates_to_email
        distribution_list_emails('dl-cds-updates')&.join(',') || ENV.fetch('CDS_UPDATES_TO_EMAILS')
      end

      def cds_updates_cc_email
        ENV.fetch('CDS_UPDATES_CC_EMAILS', '')
      end

      def cupid_team_to_emails
        emails = distribution_list_emails('dl-cupid-team')
        return emails if emails

        raw = ENV['CUPID_TEAM_TO_EMAILS']
        return [] if raw.blank?

        parse_email_list(raw)
      end

      def myott_report_email
        distribution_list_emails('dl-myott-report') || ENV['MYOTT_REPORT_EMAIL']
      end

      def search_references_report_to_emails
        emails = distribution_list_emails('dl-search-references-report')
        return emails if emails

        raw = ENV['SEARCH_REFERENCES_REPORT_TO_EMAILS']
        return [] if raw.blank?

        parse_email_list(raw)
      end

    private

      # The members of a Cognito distribution list (managed in admin), or nil
      # if the list is empty or cannot be read. On nil, callers fall back to
      # the old env var until it is removed.
      def distribution_list_emails(group_name)
        DistributionListRecipients.new.emails(group_name)
      end

      def parse_email_list(raw)
        JSON.parse(raw).values.map(&:strip).reject(&:empty?)
      rescue JSON::ParserError
        raw.split(',').map(&:strip).reject(&:empty?)
      end
    end
  end
end
