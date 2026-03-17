module Api
  module Admin
    class AdminConfigurationsController < AdminController
      include Api::Admin::VersionBrowsing

      def index
        render json: serialize(configurations)
      end

      def show
        render json: serialize(configuration, serializer_options)
      end

      def update
        configuration.set(update_params)

        if configuration.save(raise_on_failure: false)
          render json: serialize(configuration.reload, serializer_options), status: :ok
        else
          render json: serialize_errors(configuration), status: :unprocessable_content
        end
      end

      private

      def configurations
        @configurations ||= AdminConfiguration.all
      end

      def configuration
        @configuration ||= find_configuration
      end

      def find_configuration
        if filter_version_id.present? && !current_version?
          find_historical_configuration
        else
          find_current_configuration
        end
      end

      def find_current_configuration
        config = AdminConfiguration.where(name: params[:id]).first
        raise Sequel::RecordNotFound if config.blank?

        config
      end

      def find_historical_configuration
        version = versions_for_item
          .where(id: filter_version_id)
          .first

        raise Sequel::RecordNotFound if version.blank?

        version.reify
      end

      def versions_for_item
        Version.where(item_type: 'AdminConfiguration', item_id: params[:id])
      end

      def update_params
        attrs = params.require(:data).require(:attributes)
        permitted = attrs.permit(:description).to_h
        permitted[:value] = extract_value(attrs) if attrs.key?(:value)
        permitted
      end

      def extract_value(attrs)
        raw = attrs[:value]
        raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      end

      def serialize(resource, options = {})
        Api::Admin::AdminConfigurationSerializer
          .new(resource, options)
          .serializable_hash
      end

      def serialize_errors(resource)
        Api::Admin::ErrorSerializationService.new(resource).call
      end
    end
  end
end
