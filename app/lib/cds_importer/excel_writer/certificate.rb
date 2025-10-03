class CdsImporter
  class ExcelWriter
    class Certificate < BaseMapper
      def sheet_name
        'Certificates'
      end

      def table_span
        %w[A F]
      end

      def column_widths
        [30, 20, 20, 20, 20, 50]
      end

      def heading
        ['Action',
         'Certificate code type',
         'Certificate code',
         'Start date',
         'End date',
         'Description']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        certificate = grouped['Certificate'].first
        certificate_description_periods = grouped['CertificateDescriptionPeriod']
        certificate_descriptions = grouped['CertificateDescription']

        ["#{expand_operation(certificate)} certificate",
         certificate.certificate_type_code,
         certificate.certificate_code,
         format_date(certificate.validity_start_date),
         format_date(certificate.validity_end_date),
         periodic_description(certificate_description_periods, certificate_descriptions, &method(:period_matches?))]
      end

      private

      def period_matches?(period, description)
        period.certificate_description_period_sid == description.certificate_description_period_sid &&
          period.certificate_type_code == description.certificate_type_code &&
          period.certificate_code == description.certificate_code
      end
    end
  end
end
