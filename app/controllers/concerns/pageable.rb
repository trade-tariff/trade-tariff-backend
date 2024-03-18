module Pageable
  extend ActiveSupport::Concern

  included do
    def pagination_meta
      {
        meta: {
          pagination: {
            page: current_page,
            per_page: per_page,
            total_count: record_count,
          },
        },
      }
    end
  end
end
