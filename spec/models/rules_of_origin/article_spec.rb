require 'rails_helper'

RSpec.describe RulesOfOrigin::Article do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :article }
    it { is_expected.to respond_to :content }
  end

  describe '.new' do
    subject { described_class.new scheme:, article: 'test-article' }

    let(:scheme) { build :rules_of_origin_scheme, :with_articles }

    it { is_expected.to have_attributes scheme: }
    it { is_expected.to have_attributes article: 'test-article' }
    it { is_expected.to have_attributes content: "This is a test article\n\n* In markdown\n" }
  end

  describe '.for_scheme' do
    subject { described_class.for_scheme scheme }

    let(:scheme) { build :rules_of_origin_scheme, :with_articles }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all have_attributes article: 'test-article' }
    it { is_expected.to all have_attributes content: /is a test/ }

    context 'without articles' do
      let(:scheme) { build :rules_of_origin_scheme, :with_articles, scheme_code: 'unknown' }

      it { is_expected.to be_empty }
    end
  end
end
