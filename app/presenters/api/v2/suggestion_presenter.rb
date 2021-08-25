module Api
  module V2
    class SuggestionPresenter
      attr_reader :id, :value

      def initialize(id, value)
        @id = id
        @value = value
      end
    end
  end
end
