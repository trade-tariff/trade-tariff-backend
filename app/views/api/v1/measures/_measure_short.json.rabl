attributes :id

node(:vat) { |measure| measure.vat? }

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
