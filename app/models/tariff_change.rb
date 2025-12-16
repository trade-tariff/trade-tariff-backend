class TariffChange < Sequel::Model
  plugin :auto_validations, not_null: :presence
  plugin :timestamps, update_on_create: true

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid

  def measure
    return nil unless type == 'Measure'

    @measure ||= Measure.find(measure_sid: object_sid)
  end

  def self.delete_for(operation_date:)
    TariffChange.where(operation_date: operation_date).delete
  end

  dataset_module do
    def measures
      where(type: 'Measure')
    end

    def commodities
      where(type: 'Commodity')
    end

    def commodity_descriptions
      where(type: 'GoodsNomenclatureDescription')
    end

    def with_measure_criteria(trade_direction:, geographical_area:, excluded_areas: [])
      jsonb_condition = Sequel.lit("metadata IS NOT NULL AND metadata != '{}' AND metadata @> ?",
                                   Sequel.pg_jsonb({
                                     'measure' => {
                                       'trade_movement_code' => trade_direction,
                                       'geographical_area_id' => geographical_area,
                                       'excluded_geographical_area_ids' => excluded_areas.sort,
                                     },
                                   }))

      where(type: 'Measure').where(jsonb_condition)
    end

    def with_measure_type(measure_type_id)
      where(
        type: 'Measure',
        Sequel.lit("metadata->'measure'->>'measure_type_id'") => measure_type_id,
      )
    end
  end

  def measure_metadata
    metadata&.dig('measure') || {}
  end

  def measure_type_id
    measure_metadata['measure_type_id']
  end

  def trade_movement_code
    measure_metadata['trade_movement_code']
  end

  def geographical_area_id
    measure_metadata['geographical_area_id']
  end

  def excluded_geographical_area_ids
    measure_metadata['excluded_geographical_area_ids'] || []
  end

  def additional_code
    measure_metadata['additional_code']
  end

  def description
    case action
    when TariffChangesService::BaseChanges::CREATION
      "#{type} will begin"
    when TariffChangesService::BaseChanges::ENDING
      "#{type} will end"
    when TariffChangesService::BaseChanges::UPDATE
      "#{type} will be updated"
    when TariffChangesService::BaseChanges::DELETION
      "#{type} will be deleted"
    end
  end
end
