module News
  class Collection < Sequel::Model(:news_collections)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence

    many_to_many :items, join_table: :news_collections_news_items,
                         order: Sequel.desc(:start_date)
  end
end
