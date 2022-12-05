Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    trade_news = News::Collection.find_or_create(name: 'Trade news') do |collection|
      collection.slug = 'trade_news'
    end

    News::Item.eager_graph(:collections)
              .where { { collections[:id] => nil } }
              .all
              .each { |item| item.add_collection trade_news }
  end

  down do
    collection = News::Collection.find(name: 'Trade news')

    collection.items.each do |item|
      item.remove_collection collection
    end
  end
end
