module News
  class Collection < Sequel::Model(:news_collections)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence
  end
end
