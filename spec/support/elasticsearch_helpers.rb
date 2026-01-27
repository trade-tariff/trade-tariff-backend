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

    index_search_suggestion(model)
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    # Index doesn't exist yet
    false
  end

  def delete_model_from_index(model)
    index_class = INDEX_CLASS_MAP[model.class.name]

    if index_class
      TradeTariffBackend.search_client.delete(index_class, model)
    end

    delete_search_suggestion(model)
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    false
  end

  def reindex_all
    TradeTariffBackend.search_client.reindex_all
  end

  private

  def index_search_suggestion(model)
    index = Search::SearchSuggestionsIndex.new
    index_name = index.name

    if model.is_a?(SearchSuggestion)
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        index.document_id(model),
        Search::SearchSuggestionsSerializer.new(model).as_json,
      )
    elsif model.is_a?(GoodsNomenclature)
      suggestion = SearchSuggestion.build(
        id: model.goods_nomenclature_sid,
        value: model.goods_nomenclature_item_id,
        type: SearchSuggestion::TYPE_GOODS_NOMENCLATURE,
        goods_nomenclature_sid: model.goods_nomenclature_sid,
        goods_nomenclature_class: model.class.name,
      )
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        index.document_id(suggestion),
        Search::SearchSuggestionsSerializer.new(suggestion).as_json,
      )
    elsif model.instance_of?(SearchReference) && model.referenced.is_a?(GoodsNomenclature)
      suggestion = SearchSuggestion.build(
        id: model.referenced.goods_nomenclature_sid,
        value: model.title,
        type: SearchSuggestion::TYPE_SEARCH_REFERENCE,
        goods_nomenclature_sid: model.referenced.goods_nomenclature_sid,
        goods_nomenclature_class: model.referenced.class.name,
      )
      TradeTariffBackend.search_client.index_by_name(
        index_name,
        index.document_id(suggestion),
        Search::SearchSuggestionsSerializer.new(suggestion).as_json,
      )
    elsif model.instance_of?(FullChemical) && model.goods_nomenclature.present?
      gn = model.goods_nomenclature
      [
        { value: model.name, type: SearchSuggestion::TYPE_FULL_CHEMICAL_NAME },
        { value: model.cus, type: SearchSuggestion::TYPE_FULL_CHEMICAL_CUS },
        { value: model.cas_rn, type: SearchSuggestion::TYPE_FULL_CHEMICAL_CAS },
      ].each do |attrs|
        next if attrs[:value].blank?

        suggestion = SearchSuggestion.build(
          id: gn.goods_nomenclature_sid,
          value: attrs[:value],
          type: attrs[:type],
          goods_nomenclature_sid: gn.goods_nomenclature_sid,
          goods_nomenclature_class: gn.class.name,
        )
        TradeTariffBackend.search_client.index_by_name(
          index_name,
          index.document_id(suggestion),
          Search::SearchSuggestionsSerializer.new(suggestion).as_json,
        )
      end
    end
  end

  def delete_search_suggestion(model)
    index = Search::SearchSuggestionsIndex.new
    index_name = index.name

    if model.is_a?(SearchSuggestion)
      TradeTariffBackend.search_client.delete_by_name(index_name, index.document_id(model))
    elsif model.is_a?(GoodsNomenclature)
      suggestion = SearchSuggestion.new
      SearchSuggestion.unrestrict_primary_key
      suggestion.id = model.goods_nomenclature_sid
      suggestion.value = model.goods_nomenclature_item_id
      TradeTariffBackend.search_client.delete_by_name(index_name, index.document_id(suggestion))
    end
  rescue OpenSearch::Transport::Transport::Errors::NotFound
    # Document doesn't exist
    false
  end
end

RSpec.configure do |config|
  config.include ElasticsearchHelpers
end
