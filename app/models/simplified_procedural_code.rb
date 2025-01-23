class SimplifiedProceduralCode < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  def to_null_measure
    SimplifiedProceduralCodeMeasure.unrestrict_primary_key
    measure = SimplifiedProceduralCodeMeasure.new
    measure.simplified_procedural_code = simplified_procedural_code
    measure.goods_nomenclature_item_ids = self.class.codes[simplified_procedural_code]['commodities'].join(', ')
    measure.goods_nomenclature_label = goods_nomenclature_label
    measure
  end

  class << self
    def all_null_measures
      @all_null_measures ||= distinct(:simplified_procedural_code)
        .all
        .map(&:to_null_measure)
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
  end
end
