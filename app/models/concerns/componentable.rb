module Componentable
  SMALL_PRODUCERS_QUOTIENT = 'SPQ'.freeze
  LITERS_OF_PURE_ALCOHOL_QUALIFIER = 'LPA'.freeze
  LITERS_QUALIFIER = 'LTR'.freeze

  extend ActiveSupport::Concern

  included do
    plugin :time_machine

    one_to_one :duty_expression, key: :duty_expression_id,
                                 primary_key: :duty_expression_id,
                                 graph_use_association_block: true do |ds|
      ds.with_actual(DutyExpression)
    end

    one_to_one :measurement_unit, key: :measurement_unit_code,
                                  primary_key: :measurement_unit_code,
                                  graph_use_association_block: true do |ds|
      ds.with_actual(MeasurementUnit)
    end

    one_to_one :measurement_unit_qualifier, key: :measurement_unit_qualifier_code,
                                            primary_key: :measurement_unit_qualifier_code,
                                            graph_use_association_block: true do |ds|
      ds.with_actual(MeasurementUnitQualifier)
    end

    one_to_one :monetary_unit, key: :monetary_unit_code,
                               primary_key: :monetary_unit_code,
                               graph_use_association_block: true do |ds|
      ds.with_actual(MonetaryUnit)
    end

    delegate :description, :abbreviation, to: :duty_expression, prefix: true
    delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
    delegate :description, to: :monetary_unit, prefix: true, allow_nil: true

    alias_method :measurement_unit_id, :measurement_unit_code
    alias_method :measurement_unit_qualifier_id, :measurement_unit_qualifier_code

    def unit_for(measure)
      # The excise SPQ type has two variants that determine what units need
      # to be surfaced for the duty calculator.
      #
      # When the SPQ is based on litres of pure alcohol, the duty
      # calculator needs to surface the SPR and LPA compound units.
      #
      # When the SPQ is based on percentage alcohol and volume per hectolitre,
      # the duty calculator needs to surface the SPR, ASV and LTR compound units.
      #
      # This enables proper calculation of the duty and is essentially the result of a broken understanding of SPQ between CDS and other stakeholders.
      if measure.excise? && small_producers_quotient?
        if measure.all_components.find(&:liters_of_pure_alcohol?)
          {
            measurement_unit_code: SMALL_PRODUCERS_QUOTIENT,
            measurement_unit_qualifier_code: LITERS_OF_PURE_ALCOHOL_QUALIFIER,
          }
        elsif measure.all_components.find(&:percentage_alcohol_and_volume_per_hl?)
          {
            measurement_unit_code: SMALL_PRODUCERS_QUOTIENT,
            measurement_unit_qualifier_code: LITERS_QUALIFIER,
          }
        else
          {
            measurement_unit_code:,
            measurement_unit_qualifier_code:,
          }
        end
      else
        {
          measurement_unit_code:,
          measurement_unit_qualifier_code:,
        }
      end
    end

    def id
      pk.join('-')
    end

    def expresses_unit?
      measurement_unit_code.present?
    end

    def small_producers_quotient?
      measurement_unit_code == SMALL_PRODUCERS_QUOTIENT
    end

    def percentage_alcohol_and_volume_per_hl?
      measurement_unit_code == 'ASV' && measurement_unit_qualifier_code == 'X'
    end

    def liters_of_pure_alcohol?
      measurement_unit_code == 'LPA'
    end

    def ad_valorem?
      monetary_unit_code.nil? &&
        measurement_unit_code.nil?
    end

    def zero_duty?
      duty_amount&.zero?
    end

    def meursing?
      duty_expression_id.in?(DutyExpression::MEURSING_DUTY_EXPRESSION_IDS)
    end

    def duty_expression_formatter_options
      {
        duty_expression_id:,
        duty_expression_description:,
        duty_expression_abbreviation:,
        duty_amount:,
        monetary_unit: monetary_unit_code,
        monetary_unit_abbreviation:,
        measurement_unit:,
        measurement_unit_qualifier:,
      }
    end

    def formatted_duty_expression
      DutyExpressionFormatter.format(duty_expression_formatter_options.merge(formatted: true))
    end

    def verbose_duty_expression
      DutyExpressionFormatter.format(duty_expression_formatter_options.merge(verbose: true))
    end

    def duty_expression_str
      DutyExpressionFormatter.format(duty_expression_formatter_options)
    end
  end
end
