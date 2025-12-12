module TariffChanges
  class GroupedMeasureCommodityChange
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :goods_nomenclature_item_id, :string
    attribute :count, :integer
    attribute :grouped_measure_change_id, :string

    attr_accessor :commodity

    def commodity_id
      @commodity&.id
    end

    def self.from_id(id)
      parts = id.rpartition('_')
      new(
        grouped_measure_change_id: parts[0],
        goods_nomenclature_item_id: parts[2],
      )
    end

    def id
      "#{grouped_measure_change_id}_#{goods_nomenclature_item_id}"
    end

    def grouped_measure_change
      @grouped_measure_change ||= GroupedMeasureChange.from_id(grouped_measure_change_id) if grouped_measure_change_id
    end

    def measure_changes(date)
      return {} unless grouped_measure_change

      tariff_changes = TariffChange.measures
                                   .with_measure_criteria(
                                     trade_direction: grouped_measure_change.trade_direction_code,
                                     geographical_area: grouped_measure_change.geographical_area_id,
                                     excluded_areas: grouped_measure_change.excluded_geographical_area_ids&.sort || [],
                                   )
                                   .where(
                                     operation_date: date,
                                     goods_nomenclature_item_id: goods_nomenclature_item_id,
                                   )
                                   .all

      measure_type_ids = tariff_changes.map { |tc| tc.measure_metadata['measure_type_id'] }.compact.uniq
      measure_types_by_id = MeasureType.where(measure_type_id: measure_type_ids)
                                       .index_by(&:measure_type_id)

      tariff_changes.group_by { |tc|
        measure_type_id = tc.measure_metadata['measure_type_id']
        measure_type = measure_types_by_id[measure_type_id]
        measure_type&.description
      }.transform_values do |changes|
        changes.map do |change|
          {
            date_of_effect: change.date_of_effect,
            change_type: change.description,
            additional_code: change.measure_metadata['additional_code'],
          }
        end
      end
    end
  end
end
