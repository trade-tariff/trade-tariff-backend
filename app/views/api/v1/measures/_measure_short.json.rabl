attributes :id

node(:vat, &:vat?)

node(:measure_type) do |measure|
  {
    id: measure.measure_type_id,
    description: measure.measure_type.description,
  }
end
node(:duty_expression) do |measure|
  {
    base: measure.duty_expression,
    formatted_base: measure.formatted_duty_expression,
  }
end
