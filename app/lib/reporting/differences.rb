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

    GOODS_NOMENCLATURE_MEASURE_EAGER = [
      :measures,
      {
        ancestors: :measures,
        descendants: :measures,
      },
    ].freeze

    GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER = [
      :overview_measures,
      :goods_nomenclature_descriptions,
      {
        ancestors: :overview_measures,
        descendants: %i[overview_measures goods_nomenclature_descriptions],
      },
    ].freeze

    GOODS_NOMENCLATURE_OVERVIEW_MEASURE_WITH_COMPONENTS_EAGER = [
      :overview_measures,
      :goods_nomenclature_descriptions,
      {
        ancestors: [{ overview_measures: MEASURE_EAGER }],
        descendants: [
          { overview_measures: MEASURE_EAGER },
          :goods_nomenclature_descriptions,
        ],
      },
    ].freeze

    extend Reporting::Reportable

    attr_reader :package,
                :workbook,
                :regular_style,
                :bold_style,
                :centered_style,
                :as_of

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
          horizontal: :left,
          vertical: :top,
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
      @as_of = Time.zone.today.iso8601
    end

    def generate(only: [])
      total_start = Time.zone.now

      methods = %i[
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
        add_incomplete_measure_condition_worksheet
        add_me32_worksheet
        add_omitted_duty_measures_worksheet
        add_missing_vat_measure_worksheet
        add_missing_quota_origins_worksheet
        add_bad_quota_association_worksheet
        add_quota_exclusion_misalignment_worksheet
        add_measure_quota_coverage_worksheet
        add_missing_supplementary_units_from_uk_worksheet
        add_missing_supplementary_units_from_xi_worksheet
      ]

      methods = (methods & only) if only.any?

      methods.each do |method|
        start = Time.zone.now

        public_send(method)

        finish = Time.zone.now
        Rails.logger.info("Finished method '#{method}' (Duration: #{finish - start} seconds)")
      end

      total_finish = Time.zone.now
      Rails.logger.info("Finished generating worksheets (Total Duration: #{total_finish - total_start} seconds)")

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

    def add_incomplete_measure_condition_worksheet
      Reporting::Differences::IncompleteMeasureCondition.new(
        'Incomplete conditions',
        self,
      ).add_worksheet
    end

    def add_me32_worksheet
      Reporting::Differences::Me32.new(
        'ME32 candidates',
        self,
      ).add_worksheet
    end

    def add_omitted_duty_measures_worksheet
      Reporting::Differences::OmittedDutyMeasures.new(
        'Omitted duties',
        self,
      ).add_worksheet
    end

    def add_missing_vat_measure_worksheet
      Reporting::Differences::MissingVatMeasure.new(
        'VAT missing',
        self,
      ).add_worksheet
    end

    def add_missing_quota_origins_worksheet
      Reporting::Differences::QuotaMissingOrigin.new(
        'Quota with no origins',
        self,
      ).add_worksheet
    end

    def add_bad_quota_association_worksheet
      Reporting::Differences::BadQuotaAssociation.new(
        'Self-referential associations',
        self,
      ).add_worksheet
    end

    def add_quota_exclusion_misalignment_worksheet
      Reporting::Differences::QuotaExclusionMisalignment.new(
        'Exclusion misalignment',
        self,
      ).add_worksheet
    end

    def add_measure_quota_coverage_worksheet
      Reporting::Differences::MeasureQuotaCoverage.new(
        'Measure quot def coverage',
        self,
      ).add_worksheet
    end

    def add_missing_supplementary_units_from_uk_worksheet
      Reporting::Differences::SupplementaryUnit.new(
        'xi',
        'uk',
        'Supp units on EU not UK',
        self,
      ).add_worksheet
    end

    def add_missing_supplementary_units_from_xi_worksheet
      Reporting::Differences::SupplementaryUnit.new(
        'uk',
        'xi',
        'Supp units on UK not EU',
        self,
      ).add_worksheet
    end

    def uk_goods_nomenclatures
      @uk_goods_nomenclatures ||= handle_csv(Reporting::Commodities.get_uk_today)
    end

    def xi_goods_nomenclatures
      @xi_goods_nomenclatures ||= handle_csv(Reporting::Commodities.get_xi_today)
    end

    def uk_supplementary_unit_measures
      @uk_supplementary_unit_measures ||= handle_csv(Reporting::SupplementaryUnits.get_uk_today)
    end

    def xi_supplementary_unit_measures
      @xi_supplementary_unit_measures ||= handle_csv(Reporting::SupplementaryUnits.get_xi_today)
    end

    def each_chapter(eager:, as_of: Time.zone.today.iso8601)
      TimeMachine.at(as_of) do
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
      def generate(only: [])
        return if TradeTariffBackend.xi?

        package = new.generate(only:)
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
        "#{service}/reporting/#{year}/#{month}/#{day}/differences_#{now.strftime('%Y-%m-%d')}.xlsx"
      end
    end
  end
end
