attributes :id,
           :origin,
           :import,
           :goods_nomenclature_item_id

child(geographical_area: :geographical_area) do
  attributes :id

  node(:description) do |ga|
    ga.geographical_area_description.description
  end
end

node(:measure_type) do |measure|
  {
    id: measure.measure_type.id,
    description: measure.measure_type.description,
  }
end
