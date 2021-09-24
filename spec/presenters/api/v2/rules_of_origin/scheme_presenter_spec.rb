RSpec.describe Api::V2::RulesOfOrigin::SchemePresenter do
  subject(:presenter) { described_class.new scheme, rules }

  let(:scheme) { build :rules_of_origin_scheme, :with_links }

  let(:rules) do
    build_list :rules_of_origin_rule, 3, scheme_code: scheme.scheme_code
  end

  it { is_expected.to be_instance_of described_class }
  it { is_expected.to respond_to :rules }
  it { is_expected.to have_attributes rules: rules }
  it { is_expected.to have_attributes rule_ids: rules.map(&:id_rule) }
  it { is_expected.to have_attributes link_ids: scheme.links.map(&:id) }

  describe '.for_many' do
    subject(:presenters) { described_class.for_many query.schemes, query.rules }

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

      let(:scheme) do
        build :rules_of_origin_scheme, :with_links, scheme_set: scheme_set
      end

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
