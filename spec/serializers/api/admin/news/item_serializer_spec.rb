RSpec.describe Api::Admin::News::ItemSerializer do
  subject(:serialized) do
    described_class.new(news_item).serializable_hash
  end

  let(:news_item) { create :news_item, title: 'Serialized' }

  let :expected do
    {
      data: {
        id: news_item.id.to_s,
        type: :news_item,
        attributes: {
          slug: news_item.slug,
          title: 'Serialized',
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
          collection_ids: news_item.collections.map(&:id),
          created_at: news_item.created_at,
          updated_at: news_item.updated_at,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
