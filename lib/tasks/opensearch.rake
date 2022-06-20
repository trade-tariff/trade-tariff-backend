namespace :opensearch do
  namespace :search do
    desc 'Recreate a Search index then reindex the data - INDEX=model_name'
    task recreate: :environment do
      raise 'Supply an INDEX env var' if ENV['INDEX'].blank?

      TimeMachine.with_relevant_validity_periods do
        index_model = ENV['INDEX'].camelize.constantize
        TradeTariffBackend.search_client.reindex(index_model)
      end
    end

    desc 'Recreate then reindex all Search indexes'
    task recreate_all: :environment do
      TimeMachine.with_relevant_validity_periods do
        TradeTariffBackend.search_client.reindex_all
      end
    end
  end

  namespace :cache do
    desc 'Recreate a Cache index then reindex the data - INDEX=model_name'
    task recreate: :environment do
      raise 'Supply an INDEX env var' if ENV['INDEX'].blank?

      index_model = ENV['INDEX'].camelize.constantize
      TradeTariffBackend.cache_client.reindex(index_model)
    end

    desc 'Recreate then reindex all Cache indexes'
    task recreate_all: :environment do
      TradeTariffBackend.cache_client.reindex_all
    end
  end
end
