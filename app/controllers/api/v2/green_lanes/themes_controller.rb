module Api
  module V2
    module GreenLanes
      class ThemesController < BaseController
        def index
          render json: serialize(themes.to_a)
        end

        private

        def themes
          @themes ||= ::GreenLanes::Theme.order(Sequel.asc(:section), Sequel.asc(:subsection))
        end

        def serialize(*args)
          Api::V2::GreenLanes::ThemeSerializer.new(*args).serializable_hash
        end
      end
    end
  end
end
