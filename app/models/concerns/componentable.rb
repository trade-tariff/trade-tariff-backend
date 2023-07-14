module Componentable
  SMALL_PRODUCERS_QUOTIENT = 'SPQ'.freeze
  LITERS_OF_PURE_ALCOHOL_QUALIFIER = 'LPA'.freeze
  LITERS_QUALIFIER = 'LTR'.freeze

  extend ActiveSupport::Concern

  included do
    plugin :time_machine

    one_to_one :duty_expression, key: :duty_expression_id,
                                 primary_key: :duty_expression_id do |ds|
      ds.with_actual(DutyExpression)
    end

    one_to_one :measurement_unit, key: :measurement_unit_code,
                                  primary_key: :measurement_unit_code do |ds|
      ds.with_actual(MeasurementUnit)
    end

    one_to_one :measurement_unit_qualifier, key: :measurement_unit_qualifier_code,
                                            primary_key: :measurement_unit_qualifier_code do |ds|
      ds.with_actual(MeasurementUnitQualifier)
    end

    one_to_one :monetary_unit, key: :monetary_unit_code,
                               primary_key: :monetary_unit_code do |ds|
      ds.with_actual(MonetaryUnit)
    end

    delegate :description, :abbreviation, to: :duty_expression, prefix: true
    delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
    delegate :description, to: :monetary_unit, prefix: true, allow_nil: true

    def unit
      {
        measurement_unit_code:,
        measurement_unit_qualifier_code:,
      }
    end

    def expresses_unit?
      measurement_unit_code
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
  end
end
