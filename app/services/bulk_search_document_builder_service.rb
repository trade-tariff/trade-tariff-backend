# This service is responsible for accumulating negated descriptions,
# search references and intercept messages for every declarable goods nomenclature
# under a specified number of digits as the key (6 or 8, typically).
#
# The result is a presented list of document objects that can be indexed by
# Opensearch.
#
# We index declarable headings with padded 0s which seems to reflect the documented
# behaviour of the Harmonised System implementation https://www.wcoomd.org/en/topics/nomenclature/overview/what-is-the-harmonized-system.aspx.
#
# Each key may correspond to an existing goods nomenclature or a heading but
# this is not guaranteed.
#
# Instead this is an agreed-upon abstraction as part of the Windsor Framework to support bulk
# classification of searched-for goods.
class BulkSearchDocumentBuilderService
  def initialize(goods_nomenclatures, number_of_digits)
    @goods_nomenclatures = goods_nomenclatures
    @number_of_digits = number_of_digits
  end

  def call
    result = goods_nomenclatures.each_with_object({}) do |goods_nomenclature, acc|
      short_code = goods_nomenclature.goods_nomenclature_item_id.first(number_of_digits)
      indexed_tradeset_descriptions = goods_nomenclature.tradeset_descriptions.map(&:description_indexed)
      acc[short_code] ||= Hashie::TariffMash.new(
        id: short_code,
        indexed_tradeset_descriptions:,
        observed: Set.new,
        number_of_digits:,
        short_code:,
        indexed_descriptions: Set.new,
        search_references: Set.new,
        intercept_terms: Set.new,
      )

      [goods_nomenclature].concat(goods_nomenclature.ancestors).each do |applicable_goods_nomenclature|
        next if acc[short_code][:observed].include?(applicable_goods_nomenclature.goods_nomenclature_sid)

        search_references = applicable_goods_nomenclature.search_references.pluck(:title).flatten

        acc[short_code][:observed] << applicable_goods_nomenclature.goods_nomenclature_sid
        acc[short_code][:indexed_descriptions] << applicable_goods_nomenclature.description_indexed
        acc[short_code][:search_references].merge(search_references) if search_references.present?
        acc[short_code][:intercept_terms] << applicable_goods_nomenclature.intercept_terms if applicable_goods_nomenclature.intercept_terms.present?
      end
    end

    result.values.map do |document_presenter|
      document_presenter.search_references.flatten!

      document_presenter
    end
  end

  private

  attr_reader :goods_nomenclatures, :number_of_digits
end
