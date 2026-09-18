# frozen_string_literal: true

module SearchAnalytics
  # A PostgreSQL materialized view of search analytics journey data.
  # The dataset is the stored answer from expanding large JSON query results.
  # Readers query it; they do not rebuild it. refresh! replaces that stored
  # answer. These are not tariff oplog models.
  module MaterializedView
    def self.included(model)
      model.extend ClassMethods
      model.unrestrict_primary_key
    end

    module ClassMethods
      def refresh!(concurrently: true)
        keyword = concurrently ? ' CONCURRENTLY' : ''
        db.run("REFRESH MATERIALIZED VIEW#{keyword} #{table_name}")
      end
    end
  end
end
