module Api
  module V2
    module PublicUsers
      class UserPreferenceController < ApiController
        include V2Api.routes.url_helpers

        def create
          user_preference = ::PublicUsers::UserPreference.new(user_preference_params)

          if user_preference.valid? && user_preference.save
            render json: serialize(user_preference),
                   location: api_public_users_user_preference_url(user_preference.id),
                   status: :created
          else
            render json: serialize_errors(user_preference),
                   status: :unprocessable_entity
          end
        end

        def show
          user_preference = ::PublicUsers::UserPreference.where(user_id: params[:id]).first
          render json: serialize(user_preference)
        end

        private

        def user_preference_params
          params.require(:data).require(:attributes).permit(
            :user_id,
            :chapter_ids,
          )
        end

        def serialize(*args)
          Api::V2::PublicUsers::UserPreferenceSerializer.new(*args).serializable_hash
        end

        def serialize_errors(user_preference)
          Api::V2::ErrorSerializationService.new.serialized_errors(user_preference.errors)
        end
      end
    end
  end
end
