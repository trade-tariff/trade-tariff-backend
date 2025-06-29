RSpec.describe RulesOfOrigin::Article do
  let(:scheme) { build :rules_of_origin_scheme, :with_articles }

  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :article }
    it { is_expected.to respond_to :content }
  end

  describe '.new' do
    subject { described_class.new scheme:, article: 'test-article' }

    it { is_expected.to have_attributes scheme: }
    it { is_expected.to have_attributes article: 'test-article' }
    it { is_expected.to have_attributes content: "This is a test article\n\n* In markdown\n" }
  end

  describe '.for_scheme' do
    subject { described_class.for_scheme scheme }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all have_attributes article: /-article/ }
    it { is_expected.to all have_attributes content: /test/ }

    context 'without articles' do
      let(:scheme) { build :rules_of_origin_scheme, :with_articles, scheme_code: 'unknown' }

      it { is_expected.to be_empty }
    end
  end

  describe '#id' do
    subject(:article_id) { first_article.id }

    let(:first_article) { build :rules_of_origin_article, scheme: }
    let(:second_article) { build :rules_of_origin_article, scheme:, article: 'second-article' }

    let :third_article do
      build :rules_of_origin_article,
            scheme: first_article.scheme,
            article: first_article.article
    end

    it('is generated') { is_expected.to be_present }
    it('is different per instance') { is_expected.not_to eq second_article.id }
    it('is derived from scheme and article') { is_expected.to eq third_article.id }
  end
end
