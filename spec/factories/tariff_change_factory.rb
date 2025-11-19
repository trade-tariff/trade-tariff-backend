FactoryBot.define do
  factory :tariff_change do
    sequence(:object_sid) { |n| n }
    sequence(:goods_nomenclature_sid) { |n| n }
    goods_nomenclature_item_id { goods_nomenclature_sid ? sprintf('%010d', goods_nomenclature_sid) : '0000000001' }
    type { 'Commodity' }
    action { 'creation' }
    operation_date { Date.current }
    date_of_effect { Time.zone.now.to_date }
    validity_start_date { Time.zone.now }

    # Automatically populate JSONB metadata for Measure-type tariff changes
    after(:create) do |tariff_change|
      # Skip auto-population if metadata is already set (e.g., in tests)
      next if tariff_change.metadata.present? && tariff_change.metadata != {}

      if tariff_change.type == 'Measure' && tariff_change.object_sid
        measure = Measure.find(measure_sid: tariff_change.object_sid)
        if measure
          excluded_areas = measure.measure_excluded_geographical_areas_dataset
                                 .select(:excluded_geographical_area)
                                 .map(:excluded_geographical_area)
                                 .sort

          metadata = {
            'measure' => {
              'measure_type_id' => measure.measure_type_id,
              'trade_movement_code' => measure.measure_type.trade_movement_code,
              'geographical_area_id' => measure.geographical_area_id,
              'excluded_geographical_area_ids' => excluded_areas,
            },
          }

          tariff_change.update(metadata: metadata)
        end
      end
    end

    trait :update do
      action { 'update' }
    end

    trait :deletion do
      action { 'deletion' }
    end

    trait :commodity_description do
      type { 'CommodityDescription' }
    end

    trait :measure do
      type { 'Measure' }
    end
  end
end
