module Api
  module Admin
    class AppliesController < AdminController
      def create
        apply = Apply.new

        if apply.valid?
          apply.save
          render json: Api::Admin::ApplySerializer.new(apply, { is_collection: false }).serializable_hash, status: :created, location: api_applies_url
        else
          render json: Api::Admin::ErrorSerializationService.new(apply).call, status: :unprocessable_content
        end
      end
    end
  end
end
