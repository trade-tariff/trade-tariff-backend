module Api
  module V2
    class FuzzySearchPresenter
      attr_reader :result

      def initialize(result)
        @result = result
      end

      def id
        1
      end

      def type
        'fuzzy_match'
      end

      def goods_nomenclature_match
        result.results[:goods_nomenclature_match]
      end

      def reference_match
        result.results[:reference_match]
      end
    end
  end
end
