RSpec.describe Api::V2::RulesOfOrigin::SchemePresenter do
  subject(:presenter) { described_class.new scheme, rules, scheme_rule_sets }

  let(:scheme) { build :rules_of_origin_scheme, :with_links, :with_articles }
  let(:scheme_rule_sets) { build_pair :rules_of_origin_v2_rule_set }

  let(:rules) do
    build_list :rules_of_origin_rule, 3, scheme_code: scheme.scheme_code
  end

  it { is_expected.to be_instance_of described_class }
  it { is_expected.to respond_to :rules }
  it { is_expected.to have_attributes rules: }
  it { is_expected.to have_attributes rule_ids: rules.map(&:id_rule) }
  it { is_expected.to have_attributes link_ids: scheme.links.map(&:id) }
  it { is_expected.to have_attributes proof_ids: scheme.proofs.map(&:id) }
  it { is_expected.to have_attributes article_ids: scheme.articles.map(&:id) }
  it { is_expected.to have_attributes rule_set_ids: scheme_rule_sets.map(&:id) }
  it { is_expected.to have_attributes origin_reference_document_id: scheme.origin_reference_document.id }

  describe '.for_many' do
    subject(:presenters) do
      described_class.for_many query.schemes, query.rules, query.scheme_rule_sets
    end

    let(:query) do
      RulesOfOrigin::Query.new(roo_data_set, roo_heading_code, roo_country_code)
    end

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }
    it { expect(presenters[0].rules).to have_attributes length: 1 }
  end

  describe '.links' do
    subject(:presented_link_ids) { presenter.links.map(&:id) }

    context 'without scheme_set' do
      it { is_expected.to have_attributes length: 2 }
      it { is_expected.to include scheme.links.first.id }
    end

    context 'with scheme_set with extra links' do
      let(:scheme_set) { build :rules_of_origin_scheme_set }
      let(:scheme) { build :rules_of_origin_scheme, :with_links, scheme_set: }

      it { is_expected.to have_attributes length: 3 }

      it 'includes links from scheme set' do
        expect(presented_link_ids).to include scheme_set.links.first.id
      end

      it 'includes links from scheme itself' do
        expect(presented_link_ids).to include scheme.links.first.id
      end
    end
  end
end
