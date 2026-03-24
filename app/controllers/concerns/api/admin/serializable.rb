module Api
  module Admin
    module Serializable
      extend ActiveSupport::Concern

      private

      def serialize(*args)
        serializer_class.new(*args).serializable_hash
      end

      def serialize_errors(record)
        Api::Admin::ErrorSerializationService.new(record).call
      end
    end
  end
end
