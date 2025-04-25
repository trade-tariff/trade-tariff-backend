module Api
  module V2
    module News
      class ItemSerializer
        include JSONAPI::Serializer

        set_type :news_item

        attributes :id,
                   :slug,
                   :title,
                   :precis,
                   :content,
                   :display_style,
                   :show_on_xi,
                   :show_on_uk,
                   :show_on_updates_page,
                   :show_on_home_page,
                   :show_on_banner,
                   :start_date,
                   :end_date,
                   :chapters,
                   :created_at,
                   :updated_at

        has_many :collections
      end
    end
  end
end
