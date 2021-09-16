# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :news_items do
      primary_key :id
      String      :title, size: 255, null: false
      String      :content, null: false
      Integer     :display_style, null: false
      Boolean     :show_on_uk, null: false
      Boolean     :show_on_xi, null: false
      Boolean     :show_on_updates_page, null: false
      Boolean     :show_on_home_page, null: false
      Date        :start_date, null: false
      Date        :end_date
      Time        :created_at, null: false
      Time        :updated_at

      index %i[show_on_uk
               show_on_xi
               show_on_updates_page
               show_on_home_page
               start_date
               end_date]
    end
  end
end
