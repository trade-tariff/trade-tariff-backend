Sequel.migration do
  up do
    new_description = [
      ['A', 'total alcohol'],
      ['D', 'per 1% by weight of sucrose or extractable sugar'],
      ['E', 'of drained net weight'],
      ['G', ', gross'],
      ['X', 'per hectolitre'],
    ]

    new_description.each do |d|
      count = Sequel::Model.db[:measurement_unit_qualifier_descriptions]
                           .where(measurement_unit_qualifier_code: d[0])
                           .update(description: d[1])
    end
  end

  down {}
end
