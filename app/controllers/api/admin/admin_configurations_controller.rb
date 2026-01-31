module Api
  module Admin
    class AdminConfigurationsController < AdminController
      def index
        render json: serialize(configurations)
      end

      def show
        render json: serialize(configuration, serializer_options)
      end

      def update
        configuration.set(update_params)
        configuration.operation = 'U'
        configuration.operation_date = Time.zone.today

        if configuration.save_with_refresh
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
        if filter_oid.present?
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
        operation = AdminConfiguration::Operation
          .where(name: params[:id])
          .where(Sequel.lit('oid < ?', filter_oid))
          .order(Sequel.desc(:oid))
          .first

        raise Sequel::RecordNotFound if operation.blank?

        operation.record_from_oplog
      end

      def serializer_options
        { meta: version_meta }
      end

      def version_meta
        {
          version: {
            current: current_version?,
            oid: current_oid,
            previous_oid: previous_oid,
            has_previous_version: previous_oid.present?,
          },
        }
      end

      def current_oid
        @current_oid ||= viewed_operation&.oid
      end

      def previous_oid
        return @previous_oid if defined?(@previous_oid)

        viewed_oid = viewed_operation&.oid
        return @previous_oid = nil if viewed_oid.blank?

        @previous_oid = AdminConfiguration::Operation
          .where(name: params[:id])
          .where(Sequel.lit('oid < ?', viewed_oid))
          .order(Sequel.desc(:oid))
          .get(:oid)
      end

      def viewed_operation
        @viewed_operation ||= if filter_oid.present?
                                AdminConfiguration::Operation
                                  .where(name: params[:id])
                                  .where(Sequel.lit('oid < ?', filter_oid))
                                  .order(Sequel.desc(:oid))
                                  .first
                              else
                                AdminConfiguration::Operation
                                  .where(name: params[:id])
                                  .order(Sequel.desc(:oid))
                                  .first
                              end
      end

      def current_version?
        filter_oid.blank?
      end

      def filter_oid
        params.dig(:filter, :oid)&.to_i
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
