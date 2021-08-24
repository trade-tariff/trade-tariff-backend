require 'rails_helper'

RSpec.describe RulesOfOrigin::SchemeSet do
  subject(:scheme_set) { described_class.new test_file }

  let(:test_file) { Rails.root.join('db/rules_of_origin/roo_schemes_uk.json') }

  describe 'attributes' do
    it { is_expected.to respond_to :schemes }
    it { is_expected.to respond_to :countries }
    it { is_expected.to respond_to :base_path }
  end

  describe '#initialize' do
    context 'with valid file' do
      it { is_expected.to be_instance_of described_class }
      it { is_expected.to have_attributes schemes: include('EU') }
      it { is_expected.to have_attributes countries: include('FR') }
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

      it { expect { scheme_set }.to raise_exception described_class::ScopeDoesNotMatch }

      context 'with XI file' do
        let(:test_file) { Rails.root.join('db/rules_of_origin/roo_schemes_xi.json') }

        it { is_expected.to be_instance_of described_class }
      end
    end
  end

  describe '.scheme' do
    subject(:scheme) { scheme_set.scheme(scheme_code) }

    context 'for known scheme' do
      let(:scheme_code) { 'EU' }

      it { is_expected.to have_attributes scheme_code: 'EU' }
    end

    context 'for unknown scheme' do
      let(:scheme_code) { 'UNKNOWN' }

      it { expect { scheme }.to raise_exception described_class::SchemeNotFound }
    end
  end

  describe '.schemes_for_country' do
    subject(:schemes) { scheme_set.schemes_for_country(country_code) }

    context 'with matching scheme' do
      let(:country_code) { 'FR' }

      it { is_expected.to have_attributes length: 1 }
      it { is_expected.to include have_attributes(scheme_code: 'EU') }
    end

    context 'with no matching scheme' do
      let(:country_code) { 'UNKNOWN' }

      it { is_expected.to be_empty }
    end

    context 'with multiple matching schemes' do
      let(:country_code) { 'KE' }

      it { is_expected.to include have_attributes(scheme_code: 'kenya') }
      it { is_expected.to include have_attributes(scheme_code: 'gsp') }
    end
  end
end
