class QuotaUtilizationService
  attr_reader :quota_order_number_id, :from_date, :to_date

  def initialize(quota_order_number_id:, from_date: nil, to_date: nil)
    @quota_order_number_id = quota_order_number_id
    @from_date = from_date || Date.current.beginning_of_year
    @to_date = to_date || Date.current
  end

  def call
    order_number = find_order_number
    return nil unless order_number

    TimeMachine.at(to_date) do
      definitions = QuotaDefinition
        .where(quota_order_number_id:)
        .where { validity_start_date <= to_date }
        .where { Sequel.|({ validity_end_date: nil }, Sequel.expr { validity_end_date >= from_date }) }
        .order(Sequel.desc(:validity_start_date))
        .all

      return nil if definitions.empty?

      definitions.map do |definition|
        events = balance_events_in_range(definition)
        QuotaUtilizationPresenter.new(order_number, definition, events, from_date, to_date)
      end
    end
  end

private

  def find_order_number
    QuotaOrderNumber.where(quota_order_number_id:).actual.take
  end

  def balance_events_in_range(definition)
    QuotaBalanceEvent
      .where(quota_definition_sid: definition.quota_definition_sid)
      .where { occurrence_timestamp >= from_date }
      .where { occurrence_timestamp <= to_date + 1 }
      .order(:occurrence_timestamp)
      .all
  end
end
