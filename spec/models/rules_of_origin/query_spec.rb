require 'rails_helper'

RSpec.describe RulesOfOrigin::Query do
  subject(:query) do
    described_class.new roo_data_set, heading_code, country_code
  end

  let(:heading_code) { roo_heading_code }
  let(:country_code) { roo_country_code }

  include_context 'with fake rules of origin data'

  describe '#rules' do
    subject { query.rules[roo_scheme_code] }

    let(:rule_set) { roo_data_set.rule_set }

    context 'with matching heading and country code' do
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
