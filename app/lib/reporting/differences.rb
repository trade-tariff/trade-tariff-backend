module Reporting
  # Generates a report which highlights anomalies in the UK Tariff data and also
  # relies on source date about supplementary units and commodities to compare
  # the UK and XI data.
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

    MEASURE_UNIT_EAGER = [
      :measure_type,
      {
        measure_components: %i[
          measurement_unit
          measurement_unit_qualifier
        ],
        measure_conditions: [
          {
            measure_condition_components: %i[
              measurement_unit
              measurement_unit_qualifier
            ],
          },
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

    GOODS_NOMENCLATURE_MEASURE_WITH_UNIT_EAGER = [
      { measures: MEASURE_UNIT_EAGER },
      {
        ancestors: [{ measures: MEASURE_UNIT_EAGER }],
        descendants: [{ measures: MEASURE_UNIT_EAGER }],
      },
    ].freeze

    extend Reporting::Reportable

    attr_reader :workbook,
                :regular_style,
                :bold_style,
                :centered_style,
                :print_style,
                :as_of

    def initialize
      @workbook = FastExcel.open(constant_memory: true)

      @bold_style = workbook.add_format(
        bold: true,
        font_name: 'Calibri',
        font_size: 11,
      )

      @regular_style = workbook.add_format(
        align: { h: :left, v: :top },
        font_name: 'Calibri',
        font_size: 11,
        text_wrap: true,
      )

      @centered_style = workbook.add_format(
        align: { h: :center },
        font_name: 'Calibri',
        font_size: 11,
        text_wrap: true,
      )

      @print_style = workbook.add_format(
        align: { h: :left, v: :top },
        font_name: 'Courier New',
        font_size: 11,
        text_wrap: true,
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
        add_seasonal_worksheet
        add_omitted_duty_measures_worksheet
        add_missing_vat_measure_worksheet
        add_missing_quota_origins_worksheet
        add_measure_quota_coverage_worksheet
        add_bad_quota_association_worksheet
        add_quota_exclusion_misalignment_worksheet
        add_missing_supplementary_units_from_uk_worksheet
        add_missing_supplementary_units_from_xi_worksheet
        add_candidate_supplementary_units
        add_me16_worksheet
        add_overview_worksheet
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

      workbook
    end

    def add_overview_worksheet
      generate_sheet('Overview', self)
    end

    def add_missing_from_uk_worksheet
      generate_sheet('GoodsNomenclature', 'xi', 'uk', self)
    end

    def add_missing_from_xi_worksheet
      generate_sheet('GoodsNomenclature', 'uk', 'xi', self)
    end

    def add_indentation_worksheet
      generate_sheet('Indentation', self)
    end

    def add_hierarchy_worksheet
      generate_sheet('Hierarchy', self)
    end

    def add_endline_worksheet
      generate_sheet('Endline', self)
    end

    def add_start_date_worksheet
      generate_sheet('GoodsNomenclatureStartDate', self)
    end

    def add_end_date_worksheet
      generate_sheet('GoodsNomenclatureEndDate', self)
    end

    def add_mfn_missing_worksheet
      generate_sheet('MfnMissing', self)
    end

    def add_mfn_duplicated_worksheet
      generate_sheet('MfnDuplicated', self)
    end

    def add_misapplied_action_code_worksheet
      generate_sheet('MisappliedActionCode', self)
    end

    def add_incomplete_measure_condition_worksheet
      generate_sheet('IncompleteMeasureCondition', self)
    end

    def add_me32_worksheet
      generate_sheet('Me32', self)
    end

    def add_seasonal_worksheet
      generate_sheet('Seasonal', self)
    end

    def add_omitted_duty_measures_worksheet
      generate_sheet('OmittedDutyMeasures', self)
    end

    def add_missing_vat_measure_worksheet
      generate_sheet('MissingVatMeasure', self)
    end

    def add_missing_quota_origins_worksheet
      generate_sheet('QuotaMissingOrigin', self)
    end

    def add_measure_quota_coverage_worksheet
      generate_sheet('MeasureQuotaCoverage', self)
    end

    def add_bad_quota_association_worksheet
      generate_sheet('BadQuotaAssociation', self)
    end

    def add_quota_exclusion_misalignment_worksheet
      generate_sheet('QuotaExclusionMisalignment', self)
    end

    def add_missing_supplementary_units_from_uk_worksheet
      generate_sheet('SupplementaryUnit', 'xi', 'uk', self)
    end

    def add_missing_supplementary_units_from_xi_worksheet
      generate_sheet('SupplementaryUnit', 'uk', 'xi', self)
    end

    def add_candidate_supplementary_units
      generate_sheet('CandidateSupplementaryUnit', self)
    end

    def add_me16_worksheet
      generate_sheet('Me16', self)
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
          .non_classifieds
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

    def sections
      Reporting::Differences::Renderers::Overview::OVERVIEW_SECTION_CONFIG.keys.map do |section|
        worksheets = Reporting::Differences::Renderers::Overview::OVERVIEW_SECTION_CONFIG.dig(section, :worksheets).map do |worksheet, config|
          OpenStruct.new(
            worksheet:,
            worksheet_name: config[:worksheet_name],
            subtext: config[:description].sub('as_of', as_of.to_date.to_fs(:govuk)),
          )
        end

        OpenStruct.new(
          section:,
          worksheets:,
        )
      end
    end

    def uk_commodities_link
      Reporting::Commodities.get_uk_link_today
    end

    def xi_commodities_link
      Reporting::Commodities.get_xi_link_today
    end

    def uk_supplementary_units_link
      Reporting::SupplementaryUnits.get_uk_link_today
    end

    def xi_supplementary_units_link
      Reporting::SupplementaryUnits.get_xi_link_today
    end

    private

    def generate_sheet(klass, *args)
      data = Module.const_get("Reporting::Differences::Loaders::#{klass}").new(*args).get
      Module.const_get("Reporting::Differences::Renderers::#{klass}").new(*args).add_worksheet(data)
    end

    class << self
      def generate(only: [])
        return if TradeTariffBackend.xi?

        report = new
        workbook = report.generate(only:)
        workbook.close

        if Rails.env.production?
          object.put(
            body: workbook.read_string,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")

        report
      end

      private

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/differences_#{now.strftime('%Y-%m-%d')}.xlsx"
      end
    end
  end
end
