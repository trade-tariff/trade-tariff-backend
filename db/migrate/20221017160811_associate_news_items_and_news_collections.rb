Sequel.migration do
  change do
    create_join_table(collection_id: :news_collections, item_id: :news_items)
  end
end
