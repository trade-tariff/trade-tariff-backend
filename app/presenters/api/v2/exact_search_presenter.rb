module Api
  module V2
    class ExactSearchPresenter
      attr_reader :result
      
      def initialize(result)
        @result = result
      end
      
      def id
        1
      end
      
      def type
        'exact_match'
      end
      
      def entry
        {
          endpoint: result.results.class.name.parameterize(separator: '_').pluralize,
          id: result.results.to_param
        }
      end
    end
  end
end
