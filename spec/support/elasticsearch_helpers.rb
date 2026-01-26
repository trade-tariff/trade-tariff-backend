# Helper methods for explicit Elasticsearch indexing in tests
#
# Usage:
#   # Index a single model
#   index_model(commodity)
#
#   # Reindex all data
#   reindex_all
#
module ElasticsearchHelpers
  INDEX_CLASS_MAP = {
    'Commodity' => Search::CommodityIndex,
    'Chapter' => Search::ChapterIndex,
    'Heading' => Search::HeadingIndex,
    'SearchReference' => Search::SearchReferenceIndex,
  }.freeze

  def index_model(model)
    index_class = INDEX_CLASS_MAP[model.class.name]

    if index_class
      TradeTariffBackend.search_client.index(index_class, model)
    end

    index_goods_nomenclature(model)
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    # Index doesn't exist yet
    false
  end

  def delete_model_from_index(model)
    index_class = INDEX_CLASS_MAP[model.class.name]

    if index_class
      TradeTariffBackend.search_client.delete(index_class, model)
    end

    delete_goods_nomenclature(model)
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    false
  end

  def reindex_all
    TradeTariffBackend.search_client.reindex_all
  end

  private

  def index_goods_nomenclature(model)
    index_name = Search::GoodsNomenclatureIndex.new.name

    if model.is_a?(GoodsNomenclature)
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        model.id,
        Search::GoodsNomenclatureSerializer.new(model).as_json,
      )
    elsif model.instance_of?(SearchReference)
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        model.referenced.id,
        Search::GoodsNomenclatureSerializer.new(model.referenced.reload).as_json,
      )
    elsif model.instance_of?(FullChemical) && model.goods_nomenclature.present?
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        model.goods_nomenclature.id,
        Search::GoodsNomenclatureSerializer.new(model.goods_nomenclature.reload).as_json,
      )
    end
  end

  def delete_goods_nomenclature(model)
    index_name = Search::GoodsNomenclatureIndex.new.name

    if model.is_a?(GoodsNomenclature)
      TradeTariffBackend.search_client.delete_by_name(index_name, model.id)
    elsif model.instance_of?(SearchReference)
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        model.referenced.id,
        Search::GoodsNomenclatureSerializer.new(model.referenced.reload).as_json,
      )
    elsif model.instance_of?(FullChemical) && model.goods_nomenclature.present?
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        model.goods_nomenclature.id,
        Search::GoodsNomenclatureSerializer.new(model.goods_nomenclature.reload).as_json,
      )
    end
  end
end

RSpec.configure do |config|
  config.include ElasticsearchHelpers
end
