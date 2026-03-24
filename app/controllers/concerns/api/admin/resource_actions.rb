module Api
  module Admin
    # Provides standard CRUD actions for simple admin resources.
    #
    # Controllers that include this concern must define:
    #   - `resource_class`  — the Sequel model class (e.g. ::GreenLanes::Exemption)
    #   - `resource_params` — permitted ActionController::Parameters
    #   - `serializer_class` — the JSONAPI serializer class (via Api::Admin::Serializable)
    #
    # Individual actions may be overridden in the including controller when
    # the default behaviour is insufficient.
    module ResourceActions
      extend ActiveSupport::Concern

      def show
        render json: serialize(find_record)
      end

      def create
        record = resource_class.new(resource_params)
        if record.valid? && record.save
          render json: serialize(record), status: :created
        else
          render json: serialize_errors(record), status: :unprocessable_content
        end
      end

      def update
        record = find_record
        record.set(resource_params)
        if record.valid? && record.save
          render json: serialize(record), status: :ok
        else
          render json: serialize_errors(record), status: :unprocessable_content
        end
      end

      def destroy
        find_record.destroy
        head :no_content
      end

      private

      def find_record
        resource_class.with_pk!(params[:id])
      end
    end
  end
end
