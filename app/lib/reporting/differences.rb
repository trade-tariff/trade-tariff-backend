module Reporting
  class Differences
    extend Reporting::Reportable

    delegate :get, to: TariffSynchronizer::FileService

    attr_reader :package,
                :workbook,
                :regular_style,
                :bold_style,
                :centered_style

    def initialize
      @package = Axlsx::Package.new
      @package.use_shared_strings = true
      @workbook = package.workbook
      @bold_style = workbook.styles.add_style(
        b: true,
        font_name: 'Calibri',
        sz: 11,
      )
      @regular_style = workbook.styles.add_style(
        alignment: {
          wrap_text: true,
        },
        font_name: 'Calibri',
        sz: 11,
      )
      @centered_style = workbook.styles.add_style(
        alignment: {
          horizontal: :center,
          wrap_text: true,
        },
        font_name: 'Calibri',
        sz: 11,
      )
    end

    def generate
      add_missing_from_uk_worksheet
      add_missing_from_xi_worksheet
      add_indentation_worksheet
      add_endline_worksheet
      add_start_date_worksheet
      add_end_date_worksheet

      package
    end

    def add_missing_from_uk_worksheet
      Reporting::Differences::GoodsNomenclature.new(
        'xi',
        'uk',
        'Commodities in EU, not in UK',
        self,
      ).add_worksheet
    end

    def add_missing_from_xi_worksheet
      Reporting::Differences::GoodsNomenclature.new(
        'uk',
        'xi',
        'Commodities in UK, not in EU',
        self,
      ).add_worksheet
    end

    def add_indentation_worksheet
      Reporting::Differences::Indentation.new(
        'Indentation differences',
        self,
      ).add_worksheet
    end

    def add_endline_worksheet
      Reporting::Differences::Endline.new(
        'End line differences',
        self,
      ).add_worksheet
    end

    def add_start_date_worksheet
      Reporting::Differences::GoodsNomenclatureStartDate.new(
        'Start date differences',
        self,
      ).add_worksheet
    end

    def add_end_date_worksheet
      Reporting::Differences::GoodsNomenclatureEndDate.new(
        'End date differences',
        self,
      ).add_worksheet
    end

    def uk_goods_nomenclatures
      @uk_goods_nomenclatures ||= handle_csv(get("uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
    end

    def xi_goods_nomenclatures
      @xi_goods_nomenclatures ||= handle_csv(get("xi/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
    end

    def handle_csv(csv)
      CSV.parse(csv, headers: true).map(&:to_h)
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