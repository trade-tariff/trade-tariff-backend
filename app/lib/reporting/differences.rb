module Reporting
  class Differences
    extend Reporting::Reportable

    attr_reader :package, :workbook, :bold_style, :centered_style

    def initialize
      @package = Axlsx::Package.new
      @package.use_shared_strings = true
      @workbook = package.workbook
      @bold_style = workbook.styles.add_style(b: true)
      @centered_style = workbook.styles.add_style(alignment: { horizontal: :center })
    end

    def generate
      add_missing_from_uk_worksheet
      add_missing_from_xi_worksheet
      add_indentation_worksheet
      package
    end

    def add_missing_from_uk_worksheet
      Reporting::Differences::GoodsNomenclature.new(
        'xi',
        'uk',
        'Missing from UK',
        self,
      ).add_worksheet
    end

    def add_missing_from_xi_worksheet
      Reporting::Differences::GoodsNomenclature.new(
        'uk',
        'xi',
        'In UK data, not in EU',
        self,
      ).add_worksheet
    end

    def add_indentation_worksheet
      Reporting::Differences::Indentation.new(
        'Indentation differences',
        self,
      ).add_worksheet
    end

    class << self
      def generate
        return if TradeTariffBackend.xi?

        package = new.generate
        package.serialize('differences.xlsx') if Rails.env.development?

        # TODO: When all of the worksheets are produced, we should persist them to S3
        # object.put(
        #   body: package.to_stream.read,
        #   content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        # )

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/differences_#{now.strftime('%Y_%m_%d')}.xlsx"
      end
    end
  end
end
