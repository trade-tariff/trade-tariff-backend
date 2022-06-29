RSpec.describe Api::V2::RulesOfOrigin::ArticleSerializer do
  subject(:serializable) { described_class.new(article).serializable_hash }

  let(:article) { build :rules_of_origin_article, scheme: }
  let(:scheme) { build :rules_of_origin_scheme, :with_articles }

  let :expected do
    {
      data: {
        id: article.id,
        type: :rules_of_origin_article,
        attributes: {
          article: article.article,
          content: article.content,
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
