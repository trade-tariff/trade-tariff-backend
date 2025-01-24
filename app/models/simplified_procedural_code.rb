class SimplifiedProceduralCode < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  class << self
    def all_null_measures
      @all_null_measures ||= select(
        :simplified_procedural_code,
        :goods_nomenclature_label,
        Sequel.lit('ARRAY_AGG(goods_nomenclature_item_id) AS goods_nomenclature_item_ids'),
      )
                               .group(:simplified_procedural_code, :goods_nomenclature_label)
                               .map do |record|
        to_null_measure(record)
      end
    end

    def populate
      unrestrict_primary_key
      SimplifiedProceduralCode.truncate

      codes.each do |simplified_procedural_code, attributes|
        goods_nomenclature_label = attributes['label']
        attributes['commodities'].each do |goods_nomenclature_item_id|
          SimplifiedProceduralCode.find_or_create(
            simplified_procedural_code:,
            goods_nomenclature_item_id:,
            goods_nomenclature_label:,
          )
        end
      end
      restrict_primary_key
    end

    def codes
      @codes ||= begin
        file = File.read('data/simplified_procedural_codes.json')

        JSON.parse(file)['spvs']
      end
    end

    private

    def to_null_measure(record)
      SimplifiedProceduralCodeMeasure.unrestrict_primary_key
      measure = SimplifiedProceduralCodeMeasure.new
      measure.simplified_procedural_code = record.simplified_procedural_code
      measure.goods_nomenclature_label = record.goods_nomenclature_label
      measure.goods_nomenclature_item_ids = record[:goods_nomenclature_item_ids].join(', ')
      measure
    end
  end
end
