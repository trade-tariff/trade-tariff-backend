module GoodsNomenclatureIndexHelpers
  # Writes one document straight into the goods nomenclature index, so a spec
  # can run a real query against known text. Call refresh_search_indexes after
  # the last write, and delete_goods_nomenclature_document when the spec ends.
  def index_goods_nomenclature_document(goods_nomenclature_sid:, goods_nomenclature_item_id:, description:)
    index = Search::GoodsNomenclatureIndex.new

    TradeTariffBackend.search_client.index_by_name(
      index.name,
      goods_nomenclature_sid,
      {
        goods_nomenclature_sid: goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature_item_id,
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        description: description,
        formatted_description: description.capitalize,
        full_description: description.capitalize,
        declarable: true,
        validity_start_date: Time.zone.today.iso8601,
      },
    )
  end

  def delete_goods_nomenclature_document(goods_nomenclature_sid)
    TradeTariffBackend.search_client.delete_by_name(Search::GoodsNomenclatureIndex.new.name, goods_nomenclature_sid)
    refresh_search_indexes
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    false
  end

  def refresh_search_indexes
    TradeTariffBackend.search_client.indices.refresh(index: 'tariff-test-*')
  end
end

RSpec.configure do |config|
  config.include GoodsNomenclatureIndexHelpers
end
