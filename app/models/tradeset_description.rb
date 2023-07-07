class TradesetDescription < Sequel::Model
  plugin :time_machine
  plugin :validation_helpers

  many_to_one :goods_nomenclature,
              key: :goods_nomenclature_item_id,
              primary_key: :goods_nomenclature_item_id,
              condition: ->(ds) { ds.producline_suffix == '80' } do |ds|
    ds.with_actual(GoodsNomenclature)
  end

  class << self
    def build(attributes)
      description = new
      description.filename = attributes[:filename]
      description.description = attributes[:gdsdesc].to_s.strip
      description.goods_nomenclature_item_id = normalise_goods_nomenclature_item_id(attributes[:cmdtycode])
      description.created_at = attributes[:created_at]
      description.updated_at = attributes[:updated_at]
      description.classification_date = attributes[:classification_date]
      description.validity_start_date = attributes[:classification_date]
      description.validity_end_date = nil
      description
    end

    private

    def normalise_goods_nomenclature_item_id(goods_nomenclature_item_id)
      goods_nomenclature_item_id = goods_nomenclature_item_id.to_s.gsub(' ', '').first(10)

      return goods_nomenclature_item_id if goods_nomenclature_item_id.length == 10
      return '' if goods_nomenclature_item_id.blank?

      goods_nomenclature_item_id.ljust(10, '0')
    end
  end

  def description_indexed
    SearchNegationService.new(description.downcase).call
  end

  def <=>(other)
    [
      filename,
      goods_nomenclature_item_id,
      description,
    ] <=> [
      other.filename,
      other.goods_nomenclature_item_id,
      other.description,
    ]
  end

  def validate
    super

    validates_presence %w[
      goods_nomenclature_item_id
      description
      filename
      classification_date
      created_at
      updated_at
      validity_start_date
    ]
  end
end
