RSpec.describe RulesOfOrigin::Proof do
  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :summary }
    it { is_expected.to respond_to :detail }
    it { is_expected.to respond_to :proof_class }
    it { is_expected.to respond_to :subtext }
    it { is_expected.to respond_to :content }
  end

  describe '.new' do
    subject do
      described_class.new \
        'summary' => 'Proof summary',
        'detail' => 'detail.md',
        'proof_class' => 'origin-declaration',
        'subtext' => 'subtext',
        'content' => 'some content'
    end

    it { is_expected.to have_attributes summary: 'Proof summary' }
    it { is_expected.to have_attributes detail: 'detail.md' }
    it { is_expected.to have_attributes proof_class: 'origin-declaration' }
    it { is_expected.to have_attributes subtext: 'subtext' }
    it { is_expected.to have_attributes content: 'some content' }
  end

  describe '#id' do
    subject(:proof) { first_proof.id }

    let(:first_proof) { build :rules_of_origin_proof, :with_scheme, id: }
    let(:second_proof) { build :rules_of_origin_proof, :with_scheme }

    let :third_proof do
      build :rules_of_origin_proof,
            id: nil,
            summary: first_proof.summary,
            proof_class: first_proof.proof_class,
            detail: first_proof.detail,
            scheme: first_proof.scheme
    end

    context 'when supplied' do
      let(:id) { 3 }

      it { is_expected.to be 3 }
    end

    context 'when autogenerated' do
      let(:id) { nil }

      it('is generated') { is_expected.to be_present }
      it('is different per instance') { is_expected.not_to eq second_proof.id }
      it('is content addressable') { is_expected.to eq third_proof.id }
    end
  end

  describe '#url' do
    subject { build(:rules_of_origin_proof, proof_class:, scheme:).url }

    let(:scheme) { build :rules_of_origin_scheme, scheme_set: }
    let(:proof_urls) { { 'origin-declaration' => 'https://www.gov.uk/' } }
    let(:proof_class) { 'origin-declaration' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet, proof_urls: }

    context 'without proof_class' do
      let(:proof_class) { nil }

      it { is_expected.to be_nil }
    end

    context 'with proof_class' do
      context 'with scheme and scheme_set' do
        it { is_expected.to eql 'https://www.gov.uk/' }
      end

      context 'without scheme_set' do
        let(:scheme) { build(:rules_of_origin_scheme) }

        it { is_expected.to be_nil }
      end

      context 'without scheme' do
        let(:scheme) { nil }

        it { is_expected.to be_nil }
      end
    end

    context 'with unknown proof_class' do
      let(:proof_class) { 'unknown' }

      it { is_expected.to be_nil }
    end
  end

  describe '#content' do
    subject(:content) { proof.content }

    before { content }

    let(:scheme) { build :rules_of_origin_scheme, scheme_set: }
    let(:proof_class) { 'origin-declaration' }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet, read_referenced_file: 'foobar' }

    context 'when assigned directly' do
      let(:proof) { build :rules_of_origin_proof, proof_class:, scheme: }

      it { is_expected.to be_present }
      it { expect(scheme_set).not_to have_received(:read_referenced_file) }
    end

    context 'when read from file' do
      let :proof do
        build :rules_of_origin_proof, proof_class:, scheme:, content: nil
      end

      it { is_expected.to be_present }
      it { expect(scheme_set).to have_received(:read_referenced_file) }
    end
  end
end
