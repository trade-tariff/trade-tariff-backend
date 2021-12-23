atom_feed do |feed|
  feed.title 'Online Trade Tariff News Items'

  @news_items.each do |news_item|
    url = "#{TradeTariffBackend.tariff_updates_url}/#{news_item.id}"

    feed.entry(news_item, url: url) do |entry|
      entry.id           news_item.id
      entry.title        news_item.title
      entry.story_body   news_item.content
      entry.start_date   news_item.start_date.to_s(:rfc822)
      entry.end_date     news_item.end_date.to_s(:rfc822) if news_item.end_date.present?
      entry.uk           news_item.show_on_uk
      entry.xi           news_item.show_on_xi
      entry.home_page    TradeTariffBackend.tariff_home_url
      entry.updates_page TradeTariffBackend.tariff_updates_url
    end
  end
end
