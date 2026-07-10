module Api
  module V3
    module Reports
      class BaseController < Api::V3::BaseController
        def index
          render json: { data: [], meta: { total: 0 } }
        end
      end
    end
  end
end
