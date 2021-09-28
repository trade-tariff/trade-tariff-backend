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
    it { is_expected.to respond_to :proofs }
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

  describe '#proofs=' do
    subject(:proofs) { instance.proofs }

    before { instance.proofs = attributes_for_list(:rules_of_origin_proof, 2) }

    let(:instance) { described_class.new }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Proof }
    it { expect(proofs.first).to have_attributes summary: proofs.first.summary }
    it { expect(proofs.first).to have_attributes detail: proofs.first.detail }
    it { expect(proofs.first).to have_attributes scheme: instance }
  end

  describe '#proofs' do
    subject { scheme.proofs }

    context 'with proofs' do
      let(:scheme) { build :rules_of_origin_scheme, :with_proofs }

      it { is_expected.to have_attributes length: 2 }
    end

    context 'without explainers' do
      let(:scheme) { build :rules_of_origin_scheme }

      it { is_expected.to have_attributes length: 0 }
    end
  end

  describe '#fta_intro' do
    subject(:scheme) do
      build :rules_of_origin_scheme,
            fta_intro_file: intro_file,
            scheme_set: scheme_set
    end

    before do
      allow(scheme_set).to receive(:read_referenced_file)
                           .with('fta_intro', 'intro.md')
                           .and_return('fta intro content')
    end

    let(:intro_file) { 'intro.md' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }

    it 'will read the referenced file' do
      expect(scheme).to have_attributes fta_intro: 'fta intro content'
    end

    context 'with blank file' do
      let(:intro_file) { '' }

      it { expect(scheme).to have_attributes fta_intro: '' }
    end
  end

  describe '#introductory_notes' do
    subject(:scheme) do
      build :rules_of_origin_scheme,
            introductory_notes_file: notes_file,
            scheme_set: scheme_set
    end

    before do
      allow(scheme_set).to receive(:read_referenced_file)
                           .with('introductory_notes', 'notes.md')
                           .and_return('introductory notes content')
    end

    let(:notes_file) { 'notes.md' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }

    it 'will read the referenced file' do
      expect(scheme).to \
        have_attributes introductory_notes: 'introductory notes content'
    end

    context 'with blank file' do
      let(:notes_file) { '' }

      it { expect(scheme).to have_attributes introductory_notes: '' }
    end
  end
end
