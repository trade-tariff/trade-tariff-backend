RSpec.describe Api::V2::News::ItemSerializer do
  subject(:serializable) { described_class.new(news_item).serializable_hash }

  let(:news_item) { create :news_item, collection_count: 2 }

  let :expected do
    {
      data: {
        id: news_item.id.to_s,
        type: :news_item,
        attributes: {
          id: news_item.id,
          slug: news_item.slug,
          title: news_item.title,
          precis: news_item.precis,
          content: news_item.content,
          display_style: news_item.display_style,
          show_on_xi: news_item.show_on_xi,
          show_on_uk: news_item.show_on_uk,
          show_on_updates_page: news_item.show_on_updates_page,
          show_on_home_page: news_item.show_on_home_page,
          show_on_banner: news_item.show_on_banner,
          start_date: news_item.start_date,
          end_date: news_item.end_date,
          chapters: news_item.chapters,
          notify_subscribers: news_item.notify_subscribers,
          created_at: news_item.created_at,
          updated_at: news_item.updated_at,
        },
        relationships: {
          collections: {
            data: [
              {
                id: news_item.collection_ids.first.to_s,
                type: :news_collection,
              },
              {
                id: news_item.collection_ids.second.to_s,
                type: :news_collection,
              },
            ],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql expected
    end
  end
end
