module Reporting
  # Generates a report which highlights anomolies in the uk Tariff data and
  # also relies on source date about supplementary units and commodities to compare
  # the uk and xi data.
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

    attr_reader :package,
                :workbook,
                :regular_style,
                :bold_style,
                :centered_style,
                :print_style,
                :as_of,
                :overview_counts

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
      @print_style = workbook.styles.add_style(
        alignment: {
          wrap_text: true,
          horizontal: :left,
          vertical: :top,
        },
        font_name: 'Courier New',
        sz: 11,
      )
      @as_of = Time.zone.today.iso8601
      @overview_counts = Hash.new(0)
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

      package
    end

    def add_overview_worksheet
      Reporting::Differences::Overview.new(self).add_worksheet
    end

    def add_missing_from_uk_worksheet
      Reporting::Differences::GoodsNomenclature.new('xi', 'uk', self).add_worksheet
    end

    def add_missing_from_xi_worksheet
      Reporting::Differences::GoodsNomenclature.new('uk', 'xi', self).add_worksheet
    end

    def add_indentation_worksheet
      Reporting::Differences::Indentation.new(self).add_worksheet
    end

    def add_hierarchy_worksheet
      Reporting::Differences::Hierarchy.new(self).add_worksheet
    end

    def add_endline_worksheet
      Reporting::Differences::Endline.new(self).add_worksheet
    end

    def add_start_date_worksheet
      Reporting::Differences::GoodsNomenclatureStartDate.new(self).add_worksheet
    end

    def add_end_date_worksheet
      Reporting::Differences::GoodsNomenclatureEndDate.new(self).add_worksheet
    end

    def add_mfn_missing_worksheet
      Reporting::Differences::MfnMissing.new(self).add_worksheet
    end

    def add_mfn_duplicated_worksheet
      Reporting::Differences::MfnDuplicated.new(self).add_worksheet
    end

    def add_misapplied_action_code_worksheet
      Reporting::Differences::MisappliedActionCode.new(self).add_worksheet
    end

    def add_incomplete_measure_condition_worksheet
      Reporting::Differences::IncompleteMeasureCondition.new(self).add_worksheet
    end

    def add_me32_worksheet
      Reporting::Differences::Me32.new(self).add_worksheet
    end

    def add_seasonal_worksheet
      Reporting::Differences::Seasonal.new(self).add_worksheet
    end

    def add_omitted_duty_measures_worksheet
      Reporting::Differences::OmittedDutyMeasures.new(self).add_worksheet
    end

    def add_missing_vat_measure_worksheet
      Reporting::Differences::MissingVatMeasure.new(self).add_worksheet
    end

    def add_missing_quota_origins_worksheet
      Reporting::Differences::QuotaMissingOrigin.new(self).add_worksheet
    end

    def add_measure_quota_coverage_worksheet
      Reporting::Differences::MeasureQuotaCoverage.new(self).add_worksheet
    end

    def add_bad_quota_association_worksheet
      Reporting::Differences::BadQuotaAssociation.new(self).add_worksheet
    end

    def add_quota_exclusion_misalignment_worksheet
      Reporting::Differences::QuotaExclusionMisalignment.new(self).add_worksheet
    end

    def add_missing_supplementary_units_from_uk_worksheet
      Reporting::Differences::SupplementaryUnit.new('xi', 'uk', self).add_worksheet
    end

    def add_missing_supplementary_units_from_xi_worksheet
      Reporting::Differences::SupplementaryUnit.new('uk', 'xi', self).add_worksheet
    end

    def add_candidate_supplementary_units
      Reporting::Differences::CandidateSupplementaryUnit.new(self).add_worksheet
    end

    def add_me16_worksheet
      Reporting::Differences::Me16.new(self).add_worksheet
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

    def increment_count(worksheet_name)
      overview_counts[worksheet_name] += 1
    end

    def sections
      Reporting::Differences::Overview::OVERVIEW_SECTION_CONFIG.keys.map do |section|
        worksheets = Reporting::Differences::Overview::OVERVIEW_SECTION_CONFIG.dig(section, :worksheets).map do |worksheet, config|
          OpenStruct.new(
            worksheet:,
            worksheet_name: config[:worksheet_name],
            subtext: config[:description].sub('as_of', as_of.to_date.to_fs(:govuk)),
            issue_count: overview_counts[config[:worksheet_name]],
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

    class << self
      def generate(only: [])
        return if TradeTariffBackend.xi?

        report = new
        package = report.generate(only:)
        package.serialize('differences.xlsx') if Rails.env.development?

        if Rails.env.production?
          object.put(
            body: package.to_stream.read,
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
