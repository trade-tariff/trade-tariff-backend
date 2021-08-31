attributes :id,
           :origin,
           :effective_start_date,
           :effective_end_date,
           :import

node(:excise) { |measure| measure.excise? }
node(:vat)    { |measure| measure.vat? }

node(:measure_type) { |measure|
  {
    id: measure.measure_type_id,
    description: measure.measure_type.description
  }
}
node(:duty_expression) { |measure|
  {
    base: measure.duty_expression_with_national_measurement_units_for(locals[:declarable]),
    formatted_base: measure.formatted_duty_expression_with_national_measurement_units_for(locals[:declarable])
  }
}

node(:legal_acts, if: ->(measure) { !measure.national }) do |measure|
  measure.legal_acts.map do |regulation|
    partial 'api/v1/regulations/regulation', object: regulation
  end
end

node(:suspension_legal_act, if: ->(measure) { !measure.national && measure.suspended? }) do |measure|
  {
    regulation_code: regulation_code(measure.suspending_regulation),
    regulation_url: regulation_url(measure.suspending_regulation),
    validity_end_date: measure.suspending_regulation.effective_end_date,
    validity_start_date: measure.suspending_regulation.effective_start_date
  }
end

child(:measure_conditions) do
  attributes :condition_code, :condition, :document_code, :requirement, :action, :duty_expression
end

child(:geographical_area) do
  attributes :id, :description

  child(contained_geographical_areas: :children_geographical_areas) do
    attributes :id, :description
  end
end

child(excluded_geographical_areas: :excluded_countries) do
  node(:geographical_area_id) { |ga|
    ga.geographical_area_id
  }
  node(:description) { |ga|
    ga.geographical_area_description.description
  }
end

child(footnotes: :footnotes) do
  attributes :code, :description, :formatted_description
end

node(:additional_code, if: ->(measure) { measure.additional_code.present? }) do |measure|
  {
    code: measure.additional_code.code,
    description: measure.additional_code.description,
    formatted_description: measure.additional_code.formatted_description
  }
end

node(:additional_code, if: ->(measure) { measure.export_refund_nomenclature_sid.present? }) do |measure|
  {
    code: measure.export_refund_nomenclature.additional_code,
    description: measure.export_refund_nomenclature.description
  }
end

child(order_number: :order_number) do
  node(:number) { |qon| qon.quota_order_number_id }

  child(quota_definition!: :definition) do
    attributes :initial_volume, :validity_start_date, :validity_end_date, :status, :description

    node(:measurement_unit) { |qd| qd.formatted_measurement_unit }
    node(:monetary_unit) { |qd| qd.monetary_unit_code }
    node(:measurement_unit_qualifier) { |qd| qd.measurement_unit_qualifier_code }
    node(:balance) { |qd| qd.balance }
    node(:last_allocation_date) { |qd| qd.last_balance_event.try(:occurrence_timestamp) }
    node(:suspension_period_start_date) { |qd| qd.last_suspension_period.try(:suspension_start_date) }
    node(:suspension_period_end_date) { |qd| qd.last_suspension_period.try(:suspension_end_date) }
    node(:blocking_period_start_date) { |qd| qd.last_blocking_period.try(:blocking_start_date) }
    node(:blocking_period_end_date) { |qd| qd.last_blocking_period.try(:blocking_end_date) }
  end
end
