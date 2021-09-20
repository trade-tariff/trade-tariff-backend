require 'rails_helper'

RSpec.describe RulesOfOrigin::Scheme do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme_code }
    it { is_expected.to respond_to :title }
    it { is_expected.to respond_to :introductory_notes_file }
    it { is_expected.to respond_to :fta_intro_file }
    it { is_expected.to respond_to :links }
    it { is_expected.to respond_to :explainers }
    it { is_expected.to respond_to :countries }
    it { is_expected.to respond_to :rule_offset }
    it { is_expected.to respond_to :footnote }
    it { is_expected.to respond_to :adopted_by_uk }
    it { is_expected.to respond_to :country_code }
    it { is_expected.to respond_to :notes }
  end

  describe '#links=' do
    subject(:links) { instance.links }

    before { instance.links = data }

    let(:instance) { described_class.new }

    let(:data) do
      [
        { 'text' => 'HMRC', 'url' => 'https://www.hmrc.gov.uk' },
        { 'text' => 'GovUK', 'url' => 'https://www.gov.uk' },
        { 'text' => '', 'url' => '' },
      ]
    end

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Link }
    it { expect(links.first).to have_attributes text: 'HMRC' }
    it { expect(links.first).to have_attributes url: 'https://www.hmrc.gov.uk' }
  end

  describe '#links' do
    subject { scheme.links }

    context 'with links' do
      let(:scheme) { build :rules_of_origin_scheme, :with_links }

      it { is_expected.to have_attributes length: 2 }
    end

    context 'without links' do
      let(:scheme) { build :rules_of_origin_scheme }

      it { is_expected.to have_attributes length: 0 }
    end
  end

  describe '#explainers=' do
    subject(:explainers) { instance.explainers }

    before { instance.explainers = data }

    let(:instance) { described_class.new }

    let(:data) do
      [
        { 'text' => 'HMRC', 'url' => 'hmrc.md' },
        { 'text' => 'GovUK', 'url' => 'govuk.md' },
        { 'text' => '', 'url' => '' },
      ]
    end

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Explainer }
    it { expect(explainers.first).to have_attributes text: 'HMRC' }
    it { expect(explainers.first).to have_attributes url: 'hmrc.md' }
  end

  describe '#explainers' do
    subject { scheme.explainers }

    context 'with explainers' do
      let(:scheme) { build :rules_of_origin_scheme, :with_explainers }

      it { is_expected.to have_attributes length: 2 }
    end

    context 'without explainers' do
      let(:scheme) { build :rules_of_origin_scheme }

      it { is_expected.to have_attributes length: 0 }
    end
  end
end
