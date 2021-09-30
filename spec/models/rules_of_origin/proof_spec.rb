require 'rails_helper'

RSpec.describe RulesOfOrigin::Proof do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :summary }
    it { is_expected.to respond_to :detail }
  end

  describe '.new' do
    subject do
      described_class.new 'summary' => 'Proof summary', 'detail' => 'detail.md'
    end

    it { is_expected.to have_attributes summary: 'Proof summary' }
    it { is_expected.to have_attributes detail: 'detail.md' }
  end

  describe '#content' do
    subject :proof do
      build :rules_of_origin_proof, detail: proof_file, scheme: scheme
    end

    before do
      allow(scheme_set).to receive(:read_referenced_file)
                           .with('proofs', 'proof-1.md')
                           .and_return('proof content')
    end

    let(:proof_file) { 'proof-1.md' }
    let(:scheme) { build :rules_of_origin_scheme, scheme_set: scheme_set }
    let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }

    it 'will read the referenced file' do
      expect(proof).to \
        have_attributes content: 'proof content'
    end

    context 'with blank file' do
      let(:proof_file) { '' }

      it { expect(proof).to have_attributes content: '' }
    end
  end
end
