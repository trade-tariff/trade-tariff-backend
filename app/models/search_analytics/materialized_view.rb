# frozen_string_literal: true

module SearchAnalytics
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
