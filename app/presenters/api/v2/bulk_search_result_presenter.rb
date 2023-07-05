module Api
  module V2
    class BulkSearchResultPresenter < WrapDelegator
      def self.wrap(result_collection)
        result_collection.searches.each_with_object([]) do |search, acc|
          search.search_results.each do |search_result|
            acc << new(search, search_result)
          end
        end
      end

      def initialize(search, search_result)
        @search = search
        @search_result = search_result

        super(@search_result)
      end

      def input_description
        @search.input_description
      end
    end
  end
end
