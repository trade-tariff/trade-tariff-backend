class FindAncestorsService
  def initialize(goods_nomenclature_item_id)
    @goods_nomenclature_item_id = goods_nomenclature_item_id
  end

  def call
    return [] if goods_nomenclature_item_id.blank?

    goods_nomenclature.uptree.map(&:goods_nomenclature_item_id)
  end

  private

  def goods_nomenclature
    goods_nomenclature_class.by_code(goods_nomenclature_item_id).take
  end

  def goods_nomenclature_class
    GoodsNomenclature.sti_load(goods_nomenclature_item_id: goods_nomenclature_item_id).class
  end

  def goods_nomenclature_item_id
    length = @goods_nomenclature_item_id.length

    case length
    when 2 # chapter
      "#{@goods_nomenclature_item_id}00000000"
    when 4 # heading
      "#{@goods_nomenclature_item_id}000000"
    when 10 # fully-qualified
      @goods_nomenclature_item_id.to_s
    else # ilike
      ''
    end
  end
end
