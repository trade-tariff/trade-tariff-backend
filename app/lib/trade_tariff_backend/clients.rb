module TradeTariffBackend
  module Clients
    def redis
      @redis ||= Redis.new(sidekiq_redis_config)
    end

    def frontend_redis
      @frontend_redis ||= begin
        db = Rails.env.test? ? 1 : 0
        Redis.new(url: frontend_redis_url, db:)
      end
    end

    def opensearch_client
      @opensearch_client ||= OpenSearch::Client.new(opensearch_configuration)
    end

    def search_client
      @search_client ||= SearchClient.new(
        opensearch_client,
        indexes: search_indexes,
      )
    end

    def search_indexes
      [
        Search::ChapterIndex,
        Search::CommodityIndex,
        Search::HeadingIndex,
        Search::SearchReferenceIndex,
        Search::SearchSuggestionsIndex,
        Search::GoodsNomenclatureIndex,
      ].map(&:new)
    end

    def ai_client
      @ai_client ||= OpenaiClient.new
    end

    def number_formatter
      @number_formatter ||= NumberFormatter.new
    end
  end
end
