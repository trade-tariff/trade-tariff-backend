class SearchService
  class FuzzySearch < BaseSearch
    class FuzzyQuery
      attr_reader :query_string,
                  :date,
                  :index

      def initialize(query_string, date, index)
        @query_string = query_string
        @date = date
        @index = index
      end

      def match_type
        :"#{self.class.name.demodulize.chomp('Query').underscore}_match"
      end
    end
  end
end
