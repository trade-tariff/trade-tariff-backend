module Api
  module V1
    class SearchSerializationService

      def perform(result)
        result.serializable_hash.to_json
      end
    end
  end
end
