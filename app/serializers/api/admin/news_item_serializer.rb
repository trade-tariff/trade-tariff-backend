module Api
  module Admin
    class NewsItemSerializer
      include JSONAPI::Serializer

      set_type :news_item

      set_id :id

      attributes :title, :content, :display_style, :show_on_xi, :show_on_uk,
                 :show_on_updates_page, :show_on_home_page,
                 :start_date, :end_date, :created_at, :updated_at
    end
  end
end
