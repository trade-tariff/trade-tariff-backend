module Api
  module V2
    module News
      class ItemSerializer
        include JSONAPI::Serializer

        set_type :news_item

        attributes :id, :title, :content, :display_style, :show_on_xi, :show_on_uk,
                   :show_on_updates_page, :show_on_home_page, :show_on_banner,
                   :start_date, :end_date, :created_at, :updated_at
      end
    end
  end
end