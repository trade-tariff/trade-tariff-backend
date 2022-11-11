require 'rails_helper'

RSpec.describe RulesOfOrigin::SchemeSet do
  subject(:scheme_set) { described_class.from_file test_file }

  let(:test_file) { Rails.root.join('db/rules_of_origin/roo_schemes_uk.json') }

  describe 'attributes' do
    it { is_expected.to respond_to :schemes }
    it { is_expected.to respond_to :countries }
    it { is_expected.to respond_to :base_path }
    it { is_expected.to respond_to :links }
    it { is_expected.to respond_to :proof_urls }
  end

  describe '.from_file' do
    context 'with valid file' do
      it { is_expected.to be_instance_of described_class }
      it { is_expected.to have_attributes schemes: include('eu') }
      it { is_expected.to have_attributes countries: include('FR') }
      it { is_expected.to have_attributes proof_urls: include('origin-declaration') }
    end

    context 'with non existant file' do
      let(:test_file) { Rails.root.join('db/rules_of_origin/random.csv') }

      it { expect { scheme_set }.to raise_exception described_class::InvalidSchemesFile }
    end

    context 'with non json file' do
      let(:test_file) { Rails.root.join('db/Annex_3.csv') }

      it { expect { scheme_set }.to raise_exception described_class::InvalidSchemesFile }
    end

    context 'for XI service' do
      before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

      let(:test_file) { Rails.root.join('db/rules_of_origin/roo_schemes_xi.json') }

      it { is_expected.to be_instance_of described_class }
    end
  end

  describe '#scheme' do
    subject(:scheme) { scheme_set.scheme(scheme_code) }

    context 'for known scheme' do
      let(:scheme_code) { 'eu' }

      it { is_expected.to have_attributes scheme_code: 'eu' }
    end

    context 'for unknown scheme' do
      let(:scheme_code) { 'UNKNOWN' }

      it { expect { scheme }.to raise_exception described_class::SchemeNotFound }
    end
  end

  describe '#schemes_for_country' do
    subject(:schemes) { scheme_set.schemes_for_country(country_code) }

    context 'with matching scheme' do
      let(:country_code) { 'FR' }

      it { is_expected.to have_attributes length: 1 }
      it { is_expected.to include have_attributes(scheme_code: 'eu') }
    end

    context 'with no matching scheme' do
      let(:country_code) { 'UNKNOWN' }

      it { is_expected.to be_empty }
    end

    context 'with multiple matching schemes' do
      let(:country_code) { 'VN' }

      it { is_expected.to include have_attributes(scheme_code: 'vietnam') }
      it { is_expected.to include have_attributes(scheme_code: 'gsp') }
    end
  end

  describe '#links' do
    subject { scheme_set.links }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Link }
  end

  describe '#read_referenced_file' do
    subject :read_file do
      scheme_set.read_referenced_file('fta_intro', file_name)
    end

    context 'with valid file' do
      let(:file_name) { 'eu.md' }

      it { is_expected.to match 'EU Trade and Co-operation Agreement' }
    end

    context 'with odd filename' do
      let(:file_name) { 'odd?name' }

      it 'will trigger exception' do
        expect { read_file }.to raise_exception described_class::InvalidReferencedFile
      end
    end

    context 'with tree traversal filename' do
      let(:file_name) { '..' }

      it 'will trigger exception' do
        expect { read_file }.to raise_exception described_class::InvalidReferencedFile
      end
    end

    context 'with unknown file' do
      let(:file_name) { 'unknown.md' }

      it { expect { read_file }.to raise_exception Errno::ENOENT }
    end
  end

  describe '#all_schemes' do
    subject { scheme_set.all_schemes }

    it { is_expected.to eql scheme_set.schemes.map(&scheme_set.method(:scheme)) }
  end

  describe '#schemes_for_filter' do
    subject { scheme_set.schemes_for_filter(has_article: article) }

    let :scheme_set do
      build :rules_of_origin_scheme_set, schemes: [
        attributes_for(:rules_of_origin_scheme, :with_articles),
        attributes_for(:rules_of_origin_scheme),
      ]
    end

    let(:article) { scheme_set.all_schemes.first.articles.first.article }

    it { is_expected.to include scheme_set.all_schemes.first }
    it { is_expected.not_to include scheme_set.all_schemes.second }
  end
end
