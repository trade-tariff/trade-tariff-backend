RSpec.describe RulesOfOrigin::Scheme do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme_code }
    it { is_expected.to respond_to :title }
    it { is_expected.to respond_to :introductory_notes_file }
    it { is_expected.to respond_to :fta_intro_file }
    it { is_expected.to respond_to :links }
    it { is_expected.to respond_to :explainers }
    it { is_expected.to respond_to :countries }
    it { is_expected.to respond_to :footnote }
    it { is_expected.to respond_to :adopted_by_uk }
    it { is_expected.to respond_to :unilateral }
    it { is_expected.to respond_to :country_code }
    it { is_expected.to respond_to :notes }
    it { is_expected.to respond_to :proofs }
    it { is_expected.to respond_to :proof_intro }
    it { is_expected.to respond_to :proof_codes }
    it { is_expected.to respond_to :ord }
    it { is_expected.to respond_to :cumulation_methods }
    it { is_expected.to respond_to :validity_start_date }
    it { is_expected.to respond_to :validity_end_date }
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

  describe '#cumulation_methods=' do
    subject(:cumulation_methods) { instance.cumulation_methods }

    before { instance.cumulation_methods = data }

    let(:instance) { described_class.new }

    let(:expected_response) { { 'bilateral' => %w[GB CA], 'extended' => %w[EU AD], 'diagonal' => %w[EU AD] } }

    let(:data) do
      { 'bilateral' => { 'countries' => %w[GB CA] }, 'extended' => { 'countries' => %w[EU AD] }, 'diagonal' => { 'countries' => %w[EU AD] } }
    end

    it { is_expected.to include(expected_response) }

    context 'with direct countries list' do
      let(:data) { { 'bilateral' => %w[GB CA] } }

      it { is_expected.to include('bilateral' => %w[GB CA]) }
    end
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

  describe '#origin_reference_document' do
    subject(:scheme) do
      build :rules_of_origin_scheme, ord: data
    end

    let(:data) do
      {
        'ord_title' => 'Some title',
        'ord_version' => '1.1',
        'ord_date' => '28 December 2021',
        'ord_original' => '211203_ORD_Japan_V1.1.odt',
      }
    end

    let(:origin_reference_document) { scheme.origin_reference_document }

    it 'reads the origin_reference_document' do
      expect(scheme).to have_attributes ord: data
    end

    context 'with blank origin_reference_document' do
      let(:data) { '' }

      it { expect(scheme).to have_attributes ord: '' }
    end

    it { expect(origin_reference_document).to be_instance_of RulesOfOrigin::OriginReferenceDocument }
    it { expect(origin_reference_document).to have_attributes ord_title: 'Some title' }
    it { expect(origin_reference_document).to have_attributes ord_version: '1.1' }
    it { expect(origin_reference_document).to have_attributes ord_date: '28 December 2021' }
    it { expect(origin_reference_document).to have_attributes ord_original: '211203_ORD_Japan_V1.1.odt' }
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

  describe '#proof_codes' do
    context 'with defined codes' do
      subject { described_class.new(proof_codes: codes).proof_codes }

      let(:codes) { { 'ABC' => 'Hey', 'DEF' => 'there' } }

      it { is_expected.to eq codes }
    end

    context 'without defined codes' do
      subject { described_class.new.proof_codes }

      it { is_expected.to eq({}) }
    end
  end

  describe '#fta_intro' do
    subject(:scheme) do
      build :rules_of_origin_scheme,
            fta_intro_file: intro_file,
            scheme_set:
    end

    before do
      allow(scheme_set).to receive(:read_referenced_file)
                           .with('fta_intro', 'intro.md')
                           .and_return('fta intro content')
    end

    let(:intro_file) { 'intro.md' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }

    it 'reads the referenced file' do
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
            scheme_set:
    end

    before do
      allow(scheme_set).to receive(:read_referenced_file)
                           .with('introductory_notes', 'notes.md')
                           .and_return('introductory notes content')
    end

    let(:notes_file) { 'notes.md' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }

    it 'reads the referenced file' do
      expect(scheme).to \
        have_attributes introductory_notes: 'introductory notes content'
    end

    context 'with blank file' do
      let(:notes_file) { '' }

      it { expect(scheme).to have_attributes introductory_notes: '' }
    end
  end

  describe '#articles' do
    subject { scheme.articles }

    let(:scheme) { build :rules_of_origin_scheme, :with_articles }

    it { is_expected.to be_any }
    it { is_expected.to all be_instance_of RulesOfOrigin::Article }
  end

  describe '#rule_sets' do
    subject { scheme.rule_sets }

    let(:scheme) { build :rules_of_origin_scheme, :in_scheme_set, scheme_code: }

    context 'with valid rule_set' do
      let(:scheme_code) { 'test' }

      it { is_expected.to have_attributes length: 1 }
      it { is_expected.to all be_instance_of RulesOfOrigin::V2::RuleSet }
    end

    context 'with unknown rule set' do
      let(:scheme_code) { 'unknown' }

      it { is_expected.to have_attributes length: 0 }
    end
  end

  describe '#rule_sets_for_subheading' do
    subject { scheme.rule_sets_for_subheading code }

    let(:scheme) { build :rules_of_origin_scheme, rule_sets: }
    let(:rule_sets) { build_pair :rules_of_origin_v2_rule_set }

    context 'with matching subheading code' do
      let(:code) { rule_sets.first.min.first(6) }

      it { is_expected.to include rule_sets.first }
      it { is_expected.not_to include rule_sets.second }
    end

    context 'with non-matching subheading code' do
      let(:code) { (rule_sets.first.min.first(6).to_i - 1).to_s }

      it { is_expected.to be_empty }
    end
  end

  describe '#has_article?' do
    subject { scheme.has_article? article.article }

    let(:scheme) { build :rules_of_origin_scheme, :with_articles }
    let(:article) { scheme.articles.first }

    context 'with matching article' do
      it { is_expected.to be true }
    end

    context 'with matching but blank article' do
      before { allow(article).to receive(:content).and_return '' }

      it { is_expected.to be false }
    end

    context 'without matching article' do
      subject { scheme.has_article? 'something-unknown' }

      it { is_expected.to be false }
    end
  end

  describe '#validity_start_date=' do
    subject { described_class.new(validity_start_date: date).validity_start_date }

    context 'with null' do
      let(:date) { nil }

      it { is_expected.to be_nil }
    end

    context 'with blank string' do
      let(:date) { '' }

      it { is_expected.to be_nil }
    end

    context 'with date string' do
      let(:date) { '2023-01-01' }

      it { is_expected.to eq Time.utc(2023, 1, 1, 0, 0, 0).in_time_zone }
    end

    context 'with date' do
      let(:date) { Date.new(2023, 1, 1) }

      it { is_expected.to eq Time.utc(2023, 1, 1, 0, 0, 0).in_time_zone }
    end

    context 'with datetime' do
      let(:date) { Time.utc(2023, 1, 1, 10, 30, 0).in_time_zone }

      it { is_expected.to eq Time.utc(2023, 1, 1, 10, 30, 0).in_time_zone }
    end
  end

  describe '#validity_end_date=' do
    subject { described_class.new(validity_end_date: date).validity_end_date }

    context 'with null' do
      let(:date) { nil }

      it { is_expected.to be_nil }
    end

    context 'with blank string' do
      let(:date) { '' }

      it { is_expected.to be_nil }
    end

    context 'with date string' do
      let(:date) { '2023-01-01' }

      it { is_expected.to eq Time.utc(2023, 1, 1).end_of_day.in_time_zone }
    end

    context 'with date' do
      let(:date) { Date.new(2023, 1, 1) }

      it { is_expected.to eq Time.utc(2023, 1, 1).end_of_day.in_time_zone }
    end

    context 'with datetime' do
      let(:date) { Time.utc(2023, 1, 1, 10, 30, 0).in_time_zone }

      it { is_expected.to eq Time.utc(2023, 1, 1, 10, 30, 0).in_time_zone }
    end
  end

  describe '#valid_for_today?' do
    subject do
      described_class.new(validity_start_date: start_date,
                          validity_end_date: end_date)
                     .valid_for_today?
    end

    let(:start_date) { nil }
    let(:end_date) { nil }

    context 'with future start date' do
      let(:start_date) { 2.days.from_now }

      it { is_expected.to be false }
    end

    context 'with past start date' do
      let(:start_date) { 2.days.ago }

      it { is_expected.to be true }
    end

    context 'with null start and end date' do
      it { is_expected.to be true }
    end

    context 'with past end date' do
      let(:end_date) { 2.days.ago }

      it { is_expected.to be false }
    end

    context 'with future end date' do
      let(:end_date) { 2.days.from_now }

      it { is_expected.to be true }
    end
  end
end
