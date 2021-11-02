RSpec.describe Api::V2::NewsItemSerializer do
  subject(:serializable) { described_class.new(news_item).serializable_hash }

  let(:news_item) { create :news_item }

  let :expected do
    {
      data: {
        id: news_item.id.to_s,
        type: :news_item,
        attributes: {
          title: news_item.title,
          content: news_item.content,
          display_style: news_item.display_style,
          show_on_xi: news_item.show_on_xi,
          show_on_uk: news_item.show_on_uk,
          show_on_updates_page: news_item.show_on_updates_page,
          show_on_home_page: news_item.show_on_home_page,
          start_date: news_item.start_date,
          end_date: news_item.end_date,
          created_at: news_item.created_at,
          updated_at: news_item.updated_at,
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
