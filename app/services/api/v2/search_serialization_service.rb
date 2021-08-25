module Api
  module V2
    class SearchSerializationService

      def perform(result)
        klass = result.class.name.split('::').last
        presenter = "Api::V2::#{klass}Presenter".constantize.new(result)
        "Api::V2::#{klass}Serializer".constantize.new(presenter).serializable_hash
      end
    end
  end
end
