# frozen_string_literal: true

module SearchAnalytics
  # Shared behaviour for stored analytics relations that cache expensive journey
  # SQL. These are not tariff oplog models. PostgreSQL keeps the query answer on
  # disk until refresh!. Readers use the model dataset; they do not rebuild the
  # view. Refresh is a database command, not an insert.
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
