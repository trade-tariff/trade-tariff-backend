require 'rails_helper'

RSpec.describe RulesOfOrigin::Scheme do
  before do
    allow(described_class).to receive(:schemes) { scheme_data[:schemes] }
    allow(described_class).to receive(:schemes=) do |schemes|
      scheme_data[:schemes] = schemes
    end

    allow(described_class).to receive(:countries_to_schemes) { scheme_data[:countries] }
    allow(described_class).to receive(:countries_to_schemes=) do |countries|
      scheme_data[:countries] = countries
    end
  end

  let(:scheme_data) do
    {
      schemes: {},
      countries: {},
    }
  end

  let(:uk_file) { Rails.root.join('db/rules_of_origin/roo_schemes_uk.json') }

  describe '.load_from_file' do
    context 'with valid file' do
      before { described_class.load_from_file uk_file }

      it 'added to the list of schemes' do
        expect(scheme_data[:schemes]['EU']).to have_attributes(scheme_code: 'EU')
      end

      it 'is added to the countries_to_schemes index' do
        expect(scheme_data[:countries]['FR']).to include('EU')
      end
    end

    context 'with non existant file' do
      subject(:file_load) { described_class.load_from_file(test_file) }

      let(:test_file) { Rails.root.join('db/rules_of_origin/random.csv') }

      it { expect { file_load }.to raise_exception described_class::InvalidSchemesFile }
    end

    context 'with non json file' do
      subject(:file_load) { described_class.load_from_file(test_file) }

      let(:test_file) { Rails.root.join('db/Annex_3.csv') }

      it { expect { file_load }.to raise_exception described_class::InvalidSchemesFile }
    end

    context 'with unexpected attribute in file' do
      it 'will be tested'
    end

    context 'for XI service' do
      subject(:file_load) { described_class.load_from_file uk_file }

      before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

      it { expect { file_load }.to raise_exception described_class::ScopeDoesNotMatch }
    end
  end

  describe '.find' do
    subject(:scheme) { described_class.find(scheme_name) }

    before { described_class.load_from_file uk_file }

    context 'for known scheme' do
      let(:scheme_name) { 'EU' }

      it { is_expected.to have_attributes scheme_code: 'EU' }
    end

    context 'for unknown scheme' do
      let(:scheme_name) { 'UNKNOWN' }

      it { is_expected.to be_nil }
    end
  end

  describe '.for_country' do
    subject(:schemes) { described_class.for_country(country_code) }

    before { described_class.load_from_file uk_file }

    context 'with matching scheme' do
      let(:country_code) { 'FR' }

      it { is_expected.to include 'EU' }
    end

    context 'with no matching scheme' do
      let(:country_code) { 'UNKNOWN' }

      it { is_expected.to be_empty }
    end

    context 'with multiple matching schemes' do
      let(:country_code) { 'KE' }

      it { is_expected.to include 'kenya' }
      it { is_expected.to include 'gsp' }
    end
  end

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
  end

  describe '#links=' do
    subject(:links) { instance.links }

    before { instance.links = links_data }

    let(:instance) { described_class.new }

    let(:links_data) do
      [
        { text: 'HMRC', url: 'https://www.hmrc.gov.uk' },
        { text: 'GovUK', url: 'https://www.gov.uk' },
        { text: '', url: '' },
      ]
    end

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Link }
    it { expect(links.first).to have_attributes text: 'HMRC' }
    it { expect(links.first).to have_attributes url: 'https://www.hmrc.gov.uk' }
  end
end
