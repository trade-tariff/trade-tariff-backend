require 'rails_helper'

RSpec.describe RulesOfOrigin::Query do
  subject(:query) { described_class.new data_set, heading_code, country_code }

  let(:scheme_code) { data_set.scheme_set.schemes.first }
  let(:country_code) { data_set.scheme_set.scheme(scheme_code).countries.first }
  let(:heading_code) { data_set.heading_mappings.heading_codes.first }
  let(:data_set) { build :rules_of_origin_data_set }

  describe '#rules' do
    subject { query.rules }

    let(:rule) { data_set.rule_set.rule data_set.rule_set.id_rules.first }

    context 'with matching heading and country code' do
      it { is_expected.to include rule }
      it { is_expected.to have_attributes length: 1 }
    end

    context 'with unmatched country code' do
      let(:country_code) { 'RA' }

      it { is_expected.to be_empty }
    end

    context 'with unmatched heading' do
      let(:heading_code) { '011111' }

      it { is_expected.to be_empty }
    end
  end

  describe '#schemes' do
    subject { query.schemes }

    context 'with schemes matching supplied country code' do
      it { is_expected.to include data_set.scheme_set.scheme(scheme_code) }
    end

    context 'without schemes matching supplied country code' do
      let(:country_code) { 'RA' }

      it { is_expected.to be_empty }
    end
  end

  describe '#links' do
    subject { query.links }

    let(:scheme_link) { data_set.scheme_set.scheme(scheme_code).links.first }

    it { is_expected.to have_attributes length: 3 }
    it { is_expected.to include data_set.scheme_set.links.first }
    it { is_expected.to include scheme_link }
  end
end
