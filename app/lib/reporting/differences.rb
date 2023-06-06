module Reporting
  class Differences
    MEASURE_EAGER = [
      {
        measure_components: [
          { duty_expression: %i[duty_expression_description] },
          { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
          { measurement_unit_qualifier: :measurement_unit_qualifier_description },
          { monetary_unit: :monetary_unit_description },
        ],
      },
    ].freeze

    GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER = [
      :ns_overview_measures,
      :goods_nomenclature_descriptions,
      {
        ns_ancestors: :ns_overview_measures,
        ns_descendants: %i[ns_overview_measures goods_nomenclature_descriptions],
      },
    ].freeze

    GOODS_NOMENCLATURE_OVERVIEW_MEASURE_WITH_COMPONENTS_EAGER = [
      :ns_overview_measures,
      :goods_nomenclature_descriptions,
      {
        ns_ancestors: [{ ns_overview_measures: MEASURE_EAGER }],
        ns_descendants: [
          { ns_overview_measures: MEASURE_EAGER },
          :goods_nomenclature_descriptions,
        ],
      },
    ].freeze

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
      add_hierarchy_worksheet
      add_endline_worksheet
      add_start_date_worksheet
      add_end_date_worksheet
      add_mfn_missing_worksheet
      add_mfn_duplicated_worksheet
      add_misapplied_action_code_worksheet

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

    def add_hierarchy_worksheet
      Reporting::Differences::Hierarchy.new(
        'Hierarchy differences',
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

    def add_mfn_missing_worksheet
      Reporting::Differences::MfnMissing.new(
        'MFN missing',
        self,
      ).add_worksheet
    end

    def add_mfn_duplicated_worksheet
      Reporting::Differences::MfnDuplicated.new(
        'Duplicate MFNs',
        self,
      ).add_worksheet
    end

    def add_misapplied_action_code_worksheet
      Reporting::Differences::MisappliedActionCode.new(
        'Misapplied action codes',
        self,
      ).add_worksheet
    end

    def uk_goods_nomenclatures
      @uk_goods_nomenclatures ||= handle_csv(get("uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
    end

    def xi_goods_nomenclatures
      @xi_goods_nomenclatures ||= handle_csv(get("xi/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
    end

    def each_chapter(eager:)
      TimeMachine.now do
        Chapter
          .actual
          .non_hidden
          .all
          .each do |chapter|
            eager_chapter = Chapter.actual
              .where(goods_nomenclature_sid: chapter.goods_nomenclature_sid)
              .eager(eager)
              .take

            yield eager_chapter
          end
      end
    end

    def handle_csv(csv)
      CSV.parse(csv, headers: true).map(&:to_h)
    end

    class << self
      def generate
        return if TradeTariffBackend.xi?

        package = new.generate
        package.serialize('differences.xlsx') if Rails.env.development?

        if Rails.env.production?
          object.put(
            body: package.to_stream.read,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/differences_#{now.strftime('%Y_%m_%d')}.xlsx"
      end
    end
  end
end
