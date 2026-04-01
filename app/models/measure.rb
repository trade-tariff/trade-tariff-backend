class Measure < Sequel::Model
  BASE_REGULATION_ROLE = 1
  PROVISIONAL_ANTIDUMPING_ROLE = 2
  DEFINITIVE_ANTIDUMPING_ROLE = 3
  MODIFICATION_REGULATION_ROLE = 4

  # Number of days in a standard year and a leap year — used to exclude
  # year-long measures from the seasonal measures query.
  ANNUAL_DURATION_DAYS = [364, 365].freeze

  DEDUPE_SORT_ORDER = [
    Sequel.desc(:measures__measure_generating_regulation_id),
    Sequel.desc(:measures__measure_generating_regulation_role),
    Sequel.desc(:measures__measure_type_id),
    Sequel.desc(:measures__goods_nomenclature_sid),
    Sequel.desc(:measures__geographical_area_id),
    Sequel.desc(:measures__geographical_area_sid),
    Sequel.desc(:measures__additional_code_type_id),
    Sequel.desc(:measures__additional_code_id),
    Sequel.desc(:measures__ordernumber),
    Sequel.desc(:effective_start_date),
  ].freeze

  set_primary_key [:measure_sid]

  plugin :time_machine
  plugin :oplog, primary_key: :measure_sid, materialized: true
  plugin :national

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   foreign_key: :goods_nomenclature_sid,
                                   graph_use_association_block: true do |ds|
                                     ds.with_actual(GoodsNomenclature)
                                   end

  many_to_one :export_refund_nomenclature, key: :export_refund_nomenclature_sid,
                                           foreign_key: :export_refund_nomenclature_sid

  one_to_one :measure_type, primary_key: :measure_type_id,
                            key: :measure_type_id,
                            class_name: MeasureType,
                            graph_use_association_block: true do |ds|
    ds.with_actual(MeasureType)
  end

  one_to_many :measure_conditions, key: :measure_sid,
                                   order: [Sequel.asc(:condition_code), Sequel.asc(:component_sequence_number)]

  one_to_one :geographical_area, key: :geographical_area_sid,
                                 primary_key: :geographical_area_sid,
                                 class_name: GeographicalArea,
                                 graph_use_association_block: true do |ds|
    ds.with_actual(GeographicalArea)
  end

  one_to_many :measure_excluded_geographical_areas, key: :measure_sid,
                                                    primary_key: :measure_sid

  many_to_many :excluded_geographical_areas, join_table: :measure_excluded_geographical_areas,
                                             left_key: :measure_sid,
                                             left_primary_key: :measure_sid,
                                             right_key: :excluded_geographical_area,
                                             right_primary_key: :geographical_area_id,
                                             order: Sequel.asc(:geographical_area_id),
                                             class_name: 'GeographicalArea',
                                             use_optimized: true

  many_to_many :footnotes, join_table: :footnote_association_measures,
                           order: [Sequel.asc(:footnote_type_id, nulls: :first),
                                   Sequel.asc(:footnote_id, nulls: :first)],
                           left_key: :measure_sid,
                           left_primary_key: :measure_sid,
                           right_key: %i[footnote_type_id footnote_id],
                           right_primary_key: %i[footnote_type_id footnote_id],
                           graph_use_association_block: true do |ds|
                             ds.with_actual(Footnote)
                           end

  one_to_many :footnote_association_measures, key: :measure_sid, primary_key: :measure_sid

  one_to_many :measure_components, key: :measure_sid, order: Sequel.asc(:duty_expression_id)

  one_to_one :additional_code, key: :additional_code_sid,
                               primary_key: :additional_code_sid,
                               graph_use_association_block: true do |ds|
    ds.with_actual(AdditionalCode)
  end

  one_to_one :meursing_additional_code, key: :meursing_additional_code_sid,
                                        primary_key: :additional_code_sid,
                                        graph_use_association_block: true do |ds|
    ds.with_actual(MeursingAdditionalCode)
  end

  many_to_one :additional_code_type, class_name: 'AdditionalCodeType',
                                     key: :additional_code_type_id,
                                     primary_key: :additional_code_type_id

  one_to_one :quota_order_number, key: :quota_order_number_id,
                                  primary_key: :ordernumber,
                                  graph_use_association_block: true do |ds|
    ds.with_actual(QuotaOrderNumber).order(Sequel.desc(:validity_start_date))
  end

  one_to_one :quota_definition, key: :quota_order_number_id,
                                primary_key: :ordernumber,
                                graph_use_association_block: true do |ds|
    ds.with_actual(QuotaDefinition).order(Sequel.desc(:validity_start_date))
  end

  many_to_many :full_temporary_stop_regulations, join_table: :fts_regulation_actions,
                                                 left_primary_key: :measure_generating_regulation_id,
                                                 left_key: :stopped_regulation_id,
                                                 right_key: :fts_regulation_id,
                                                 right_primary_key: :full_temporary_stop_regulation_id,
                                                 graph_use_association_block: true do |ds|
                                                   ds.with_actual(FullTemporaryStopRegulation)
                                                 end

  one_to_many :category_assessments,
              class: 'CategoryAssessment',
              class_namespace: 'GreenLanes',
              key: %i[measure_type_id regulation_id regulation_role],
              primary_key: %i[measure_type_id
                              measure_generating_regulation_id
                              measure_generating_regulation_role]

  delegate :rules_of_origin_apply?,
           :third_country?,
           :excise?,
           :vat?,
           :preferential_quota?,
           :tariff_preference?,
           :supplementary?,
           :trade_remedy?, to: :measure_type, allow_nil: true

  delegate :gsp_or_dcts?, to: :geographical_area, allow_nil: true

  def universal_waiver_applies?
    measure_conditions.any?(&:universal_waiver_applies?)
  end

  def full_temporary_stop_regulation
    full_temporary_stop_regulations.first
  end

  one_to_many :measure_partial_temporary_stops, primary_key: :measure_sid,
                                                key: :measure_sid,
                                                graph_use_association_block: true do |ds|
                                                  ds.with_actual(MeasurePartialTemporaryStop)
                                                end

  def measure_partial_temporary_stop
    measure_partial_temporary_stops.first
  end

  many_to_one :modification_regulation, primary_key: %i[modification_regulation_id
                                                        modification_regulation_role],
                                        key: %i[measure_generating_regulation_id
                                                measure_generating_regulation_role],
                                        conditions: { approved_flag: true }

  many_to_one :base_regulation, primary_key: %i[base_regulation_id
                                                base_regulation_role],
                                key: %i[measure_generating_regulation_id
                                        measure_generating_regulation_role],
                                conditions: { approved_flag: true }

  def validity_start_date
    self[:validity_start_date].presence || generating_regulation.validity_start_date
  end

  def validity_end_date
    Measure::ValidityPeriod.new(self).end_date
  end

  def generating_regulation
    @generating_regulation ||= if measure_generating_regulation_role == MODIFICATION_REGULATION_ROLE
                                 modification_regulation
                               else
                                 base_regulation
                               end
  end

  def justification_regulation
    @justification_regulation ||= if justification_regulation_role == MODIFICATION_REGULATION_ROLE
                                    ModificationRegulation.find(modification_regulation_id: justification_regulation_id,
                                                                modification_regulation_role: justification_regulation_role)
                                  else
                                    BaseRegulation.find(base_regulation_id: justification_regulation_id,
                                                        base_regulation_role: justification_regulation_role)
                                  end
  end

  def legal_acts
    return [] if national?

    result = []
    result << suspending_regulation
    result << generating_regulation
    result << generating_regulation.base_regulation if measure_generating_regulation_role == MODIFICATION_REGULATION_ROLE
    result.compact
  end

  dataset_module do
    def with_additional_code_sid(additional_code_sid)
      return self if additional_code_sid.blank?

      where(additional_code_sid:)
    end

    def with_additional_code_type(additional_code_type_id)
      return self if additional_code_type_id.blank?

      where(additional_code_type_id:)
    end

    def with_additional_code_id(additional_code_id)
      return self if additional_code_id.blank?

      where(additional_code_id:)
    end

    def join_measure_conditions
      association_right_join(:measure_conditions)
        .where(Sequel.~(measures__measure_sid: nil))
    end

    def with_certificate_type_code(type)
      return self if type.blank?

      where(measure_conditions__certificate_type_code: type)
    end

    def with_certificate_code(code)
      return self if code.blank?

      where(measure_conditions__certificate_code: code)
    end

    def with_certificate_types_and_codes(certificate_types_and_codes)
      combine_pair_conditions(
        certificate_types_and_codes,
        :measure_conditions__certificate_type_code,
        :measure_conditions__certificate_code,
      )
    end

    def join_footnotes
      association_right_join(:footnotes)
        .exclude(measures__measure_sid: nil)
    end

    def with_footnote_type_id(footnote_type_id)
      return self if footnote_type_id.blank?

      where(footnotes__footnote_type_id: footnote_type_id)
    end

    def with_footnote_id(footnote_id)
      return self if footnote_id.blank?

      where(footnotes__footnote_id: footnote_id)
    end

    def with_footnote_types_and_ids(footnote_types_and_ids)
      combine_pair_conditions(
        footnote_types_and_ids,
        :footnotes__footnote_type_id,
        :footnotes__footnote_id,
      )
    end

    def with_measure_type(condition_measure_type)
      where(measures__measure_type_id: condition_measure_type.to_s)
    end

    def valid_since(first_effective_timestamp)
      where('measures.validity_start_date >= ?', first_effective_timestamp)
    end

    def valid_to(last_effective_timestamp)
      where('measures.validity_start_date <= ?', last_effective_timestamp)
    end

    def valid_before(last_effective_timestamp)
      where('measures.validity_start_date < ?', last_effective_timestamp)
    end

    def valid_from(timestamp)
      where('measures.validity_start_date >= ?', timestamp)
    end

    def not_terminated
      where('measures.validity_end_date IS NULL')
    end

    def terminated
      where('measures.validity_end_date IS NOT NULL')
    end

    def with_gono_id(goods_nomenclature_item_id)
      where(goods_nomenclature_item_id:)
    end

    def with_tariff_measure_number(tariff_measure_number)
      where(tariff_measure_number:)
    end

    def with_geographical_area(area)
      where(geographical_area_id: area)
    end

    def with_duty_amount(amount)
      join_table(:left, MeasureComponent, measures__measure_sid: :measure_components__measure_sid)
      .where(measure_components__duty_amount: amount)
    end

    def effective_start_date_column
      Sequel.function(:coalesce,
                      :measures__validity_start_date,
                      :base_regulation__validity_start_date,
                      :modification_regulation__validity_start_date)
    end

    def effective_end_date_column
      Sequel.function(:coalesce,
                      :measures__validity_end_date,
                      :base_regulation__effective_end_date,
                      :base_regulation__validity_end_date,
                      :modification_regulation__effective_end_date,
                      :modification_regulation__validity_end_date)
    end

    def with_generating_regulation
      association_left_join(:base_regulation, :modification_regulation)
        .where do |_query|
          (Sequel.qualify(:base_regulation, :base_regulation_id) !~ nil) |
            (Sequel.qualify(:modification_regulation, :modification_regulation_id) !~ nil)
        end
    end

    def with_regulation_dates_query_non_current
      with_generating_regulation
        .select_append(Sequel.as(effective_start_date_column, :effective_start_date))
        .select_append(Sequel.as(effective_end_date_column, :effective_end_date))
    end

    def with_regulation_dates_query
      with_generating_regulation
        .select_append(Sequel.as(effective_start_date_column, :effective_start_date))
        .select_append(Sequel.as(effective_end_date_column, :effective_end_date))
        .where do |_query|
          if model.point_in_time
            start_date = effective_start_date_column
            end_date   = effective_end_date_column

            (start_date <= model.point_in_time) &
              ((end_date >= model.point_in_time) | (end_date =~ nil))
          else
            true # .where method needs _something_ to AND to the query
          end
        end
    end

    def with_seasonal_measures(measure_type_ids, geographical_area_ids)
      start_of_range = Time.zone.today.beginning_of_year
      end_of_range = Time.zone.today.end_of_year + 1.year

      select(
        :measure_sid,
        :goods_nomenclature_item_id,
        :measure_type_id,
        :geographical_area_id,
        :validity_start_date,
        :validity_end_date,
      )
        .where(measure_type_id: measure_type_ids)
        .where(geographical_area_id: geographical_area_ids)
        .exclude(validity_end_date: nil)
        .where('validity_start_date >= ?', start_of_range)
        .where('validity_end_date <= ?', end_of_range)
        .where(Sequel.lit('(validity_end_date::date - validity_start_date::date) NOT IN ?', ANNUAL_DURATION_DAYS))
    end

    def dedupe_similar
      # Needs with_regulation_dates_query and only works within time machine but should be used before not after
      select(Sequel.expr(:measures).*)
        .distinct(:measure_generating_regulation_id,
                  :measure_generating_regulation_role,
                  :measure_type_id,
                  :goods_nomenclature_sid,
                  :geographical_area_id,
                  :geographical_area_sid,
                  :additional_code_type_id,
                  :additional_code_id,
                  :ordernumber)
        .order(*DEDUPE_SORT_ORDER)
    end

    def without_excluded_types
      exclude(measures__measure_type_id: MeasureType.excluded_measure_types)
    end

    def overview
      where do
        overview_types = [
          { measures__measure_type_id: MeasureType::SUPPLEMENTARY_TYPES },
          {
            measures__measure_type_id: MeasureType::THIRD_COUNTRY,
            measures__geographical_area_id: GeographicalArea::ERGA_OMNES_ID,
          },
        ]

        overview_types << if TradeTariffBackend.uk?
                            {
                              measures__measure_type_id: MeasureType::VAT_TYPES,
                              measures__geographical_area_id: GeographicalArea::AREAS_SUBJECT_TO_VAT_OR_EXCISE_ID,
                            }
                          else

                            {
                              measures__measure_type_id: MeasureType::VAT_TYPES,
                              measures__geographical_area_id: GeographicalArea::ERGA_OMNES_ID,
                            }

                          end

        Sequel.|(*overview_types)
      end
    end

    def excluding_licensed_quotas
      exclusion_criteria = Sequel.|(
        *QuotaOrderNumber::LICENSED_QUOTA_PREFIXES.map do |prefix|
          Sequel.like(:ordernumber, "#{prefix}%")
        end,
      )

      exclude(exclusion_criteria)
    end

    private

    # Builds an OR-combined Sequel condition from a collection of [col_a, col_b]
    # value pairs and applies it as a WHERE clause. Returns the dataset unchanged
    # if the pairs collection is empty.
    def combine_pair_conditions(pairs, col_a, col_b)
      return self if pairs.none?

      conditions = pairs.map { |a, b| Sequel.expr(col_a => a) & Sequel.expr(col_b => b) }
      where(conditions.reduce(:|))
    end
  end

  def_column_accessor :effective_end_date, :effective_start_date

  def national?
    national
  end

  def justification_regulation_present?
    justification_regulation_role.present? && justification_regulation_id.present?
  end

  def generating_regulation_present?
    measure_generating_regulation_id.present? && measure_generating_regulation_role.present?
  end

  def measure_generating_regulation_id
    result = self[:measure_generating_regulation_id]

    # https://www.pivotaltracker.com/story/show/35164477
    case result
    when 'D9500019'
      'D9601421'
    else
      result
    end
  end

  def id
    measure_sid
  end

  def origin
    if measure_sid >= 0
      'eu'
    else
      'uk'
    end
  end

  def import
    measure_type.present? && measure_type.trade_movement_code.in?(MeasureType::IMPORT_MOVEMENT_CODES)
  end

  def export
    measure_type.present? && measure_type.trade_movement_code.in?(MeasureType::EXPORT_MOVEMENT_CODES)
  end

  def suspended?
    full_temporary_stop_regulation.present? || measure_partial_temporary_stop.present?
  end

  def suspending_regulation
    full_temporary_stop_regulation.presence || measure_partial_temporary_stop
  end

  def suspending_regulation_id
    suspending_regulation&.regulation_id
  end

  def duty_expression
    duty_expression_presenter.plain
  end

  def supplementary_unit_duty_expression
    duty_expression_presenter.supplementary_unit
  end

  def formatted_duty_expression
    duty_expression_presenter.formatted
  end

  def verbose_duty_expression
    duty_expression_presenter.verbose
  end

  def order_number
    if quota_order_number.present?
      quota_order_number
    elsif ordernumber.present?
      # TODO: refactor if possible
      qon = QuotaOrderNumber.new(quota_order_number_id: ordernumber)
      qon.associations[:quota_definition] = nil
      qon
    end
  end

  def relevant_for_country?(country_id)
    Measure::GeographicalRelevance.new(self).relevant_for?(country_id)
  end

  def erga_omnes?
    geographical_area_id == GeographicalArea::ERGA_OMNES_ID
  end

  def self.changes_for(depth = 1, conditions = {})
    operation_klass.select(
      Sequel.as(Sequel.cast_string('Measure'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth),
    ).where(conditions)
     .where { |o| o.<=(:validity_start_date, point_in_time) }
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last))
  end

  def meursing?
    measure_components.any?(&:meursing?)
  end

  alias_method :meursing, :meursing?

  def zero_mfn?
    return false unless third_country?
    return false unless measure_components.count == 1

    measure_components.first.zero_duty?
  end

  delegate :expresses_unit?, :ad_valorem?, :units, to: :component_resolver

  def entry_price_system?
    measure_conditions && measure_conditions.any?(&:entry_price_system?)
  end

  def resolved_duty_expression
    duty_expression_presenter.resolved
  end

  def resolved_measure_components
    component_resolver.resolved_components
  end

  delegate :meursing_measures, to: :component_resolver

  include Orderable

  delegate :all_components, to: :component_resolver

  def resolves_meursing_measures?
    component_resolver.resolves_meursing?
  end

  def duty_expression_presenter
    @duty_expression_presenter ||= Measure::DutyExpressionPresenter.new(self)
  end

  def component_resolver
    @component_resolver ||= Measure::ComponentResolver.new(self)
  end
end
