require 'rails_helper'

RSpec.describe RulesOfOrigin::Proof do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :summary }
    it { is_expected.to respond_to :detail }
    it { is_expected.to respond_to :proof_class }
    it { is_expected.to respond_to :subtext }
  end

  describe '.new' do
    subject do
      described_class.new \
        'summary' => 'Proof summary',
        'detail' => 'detail.md',
        'proof_class' => 'origin-declaration',
        'subtext' => 'subtext'
    end

    it { is_expected.to have_attributes summary: 'Proof summary' }
    it { is_expected.to have_attributes detail: 'detail.md' }
    it { is_expected.to have_attributes proof_class: 'origin-declaration' }
    it { is_expected.to have_attributes subtext: 'subtext' }
  end

  describe '#url' do
    subject do
      build(:rules_of_origin_proof, proof_class: proof_class, scheme: scheme).url
    end

    let(:scheme) { build :rules_of_origin_scheme, scheme_set: scheme_set }
    let(:proof_urls) { { 'origin-declaration' => 'https://www.gov.uk/' } }
    let(:proof_class) { 'origin-declaration' }

    let(:scheme_set) do
      instance_double RulesOfOrigin::SchemeSet, proof_urls: proof_urls
    end

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
end
