module Api
  module Admin
    module GreenLanes
      class UpdateNotificationsController < AdminController
        include Pageable
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(update_notifications.to_a, pagination_meta)
        end

        def show
          update = ::GreenLanes::UpdateNotification.with_pk!(params[:id])
          render json: serialize(update)
        end

        def update
          update = ::GreenLanes::UpdateNotification.with_pk!(params[:id])
          update.status = 9

          if update.save
            render json: serialize(update),
                   status: :ok
          else
            render json: serialize_errors(update),
                   status: :unprocessable_entity
          end
        end

        private

        def record_count
          @update_notifications.pagination_record_count
        end

        def update_notifications
          @update_notifications ||= ::GreenLanes::UpdateNotification
                                      .where(Sequel.lit('status != ?', ::GreenLanes::UpdateNotification::NotificationStatus::INACTIVE))
                                      .order(Sequel.asc(:id)).paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::UpdateNotificationSerializer.new(*args).serializable_hash
        end

        def serialize_errors(update)
          Api::Admin::ErrorSerializationService.new(update).call
        end
      end
    end
  end
end
