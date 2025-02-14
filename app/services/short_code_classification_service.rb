class ShortCodeClassificationService
  def initialize(short_code)
    @short_code = short_code
  end

  def call
    goods_nomenclature_item_id = short_code.ljust(10, '0')
    productline_suffix = '80'

    return ['Chapter', goods_nomenclature_item_id, productline_suffix] if short_code.length == 1
    return ['Chapter', goods_nomenclature_item_id, productline_suffix] if short_code.length == 2
    return ['Subheading', goods_nomenclature_item_id, productline_suffix] if [6, 8].include?(short_code.length)
    return ['Commodity', goods_nomenclature_item_id, productline_suffix] if short_code.length == 10

    if short_code.match?(/\d{10}-\d{2}/)
      goods_nomenclature_item_id = short_code.first(10)
      productline_suffix = short_code.last(2)

      return ['Subheading', goods_nomenclature_item_id, productline_suffix]
    end

    goods_nomenclature_item_id = short_code.first(4).ljust(10, '0')
    goods_nomenclature_class = 'Heading'

    [goods_nomenclature_class, goods_nomenclature_item_id, productline_suffix]
  end

  private

  attr_reader :short_code
end
