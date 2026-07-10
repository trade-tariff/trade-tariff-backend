module Api
  module V3
    class SearchSerializationService
      def perform(result)
        klass = result.class.name.split('::').last
        presenter = "Api::V2::#{klass}Presenter".constantize.new(result)
        "Api::V3::#{klass}Serializer".constantize.call(presenter)
      end
    end
  end
end
