require 'rails_helper'

RSpec.describe RulesOfOrigin::Query do
  subject(:query) do
    described_class.new roo_data_set, heading_code, country_code
  end

  include_context 'with fake rules of origin data'

  let(:heading_code) { roo_heading_code }
  let(:country_code) { roo_country_code }
  let(:commodity_code) { "#{roo_heading_code}1010" }

  describe '.new' do
    it { is_expected.to be_instance_of described_class }

    context 'with full commodity code' do
      let(:heading_code) { commodity_code }

      it { is_expected.to be_instance_of described_class }
    end

    context 'with invalid heading code' do
      let(:heading_code) { '1000' }

      it { expect { query }.to raise_exception described_class::InvalidParams }
    end

    context 'with invalid country code' do
      let(:country_code) { 'USA' }

      it { expect { query }.to raise_exception described_class::InvalidParams }
    end
  end

  describe '#rules' do
    subject { query.rules[roo_scheme_code] }

    let(:rule_set) { roo_data_set.rule_set }

    context 'with matching heading and country code' do
      it { is_expected.to include rule_set.rule(rule_set.id_rules.first) }
      it { is_expected.to have_attributes length: 1 }
    end

    context 'with matching commodity code and country code' do
      let(:heading_code) { commodity_code }

      it { is_expected.to include rule_set.rule(rule_set.id_rules.first) }
      it { is_expected.to have_attributes length: 1 }
    end

    context 'with unmatched country code' do
      let(:country_code) { 'RA' }

      it { expect(query.rules).to be_empty }
    end

    context 'with unmatched heading' do
      let(:heading_code) { '011111' }

      it { expect(query.rules).to be_empty }
    end
  end

  describe '#schemes' do
    subject { query.schemes }

    context 'with matching commodity code and country code' do
      let(:heading_code) { commodity_code }

      it { is_expected.to include roo_scheme }
    end

    context 'with schemes matching supplied country code' do
      it { is_expected.to include roo_scheme }
    end

    context 'without schemes matching supplied country code' do
      let(:roo_country_code) { 'RA' }

      it { is_expected.to be_empty }
    end
  end

  describe '#links' do
    subject { query.links }

    it { is_expected.to have_attributes length: 3 }
    it { is_expected.to include roo_data_set.scheme_set.links.first }
    it { is_expected.to include roo_scheme.links.first }
  end
end
