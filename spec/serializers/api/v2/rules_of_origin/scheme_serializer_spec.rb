RSpec.describe Api::V2::RulesOfOrigin::SchemeSerializer do
  subject { serializer.serializable_hash }

  let(:scheme_set) { build :rules_of_origin_scheme_set, links: [], schemes: [] }
  let(:scheme) { build :rules_of_origin_scheme, scheme_set: scheme_set }

  let(:rules) do
    build_list :rules_of_origin_rule, 3, scheme_code: scheme.scheme_code
  end

  let :serializer do
    described_class.new \
      Api::V2::RulesOfOrigin::SchemePresenter.new(scheme, rules),
      include: %i[rules]
  end

  let :expected do
    {
      data: {
        id: scheme.scheme_code,
        type: :rules_of_origin_scheme,
        attributes: {
          scheme_code: scheme.scheme_code,
          title: scheme.title,
          countries: scheme.countries,
          footnote: scheme.footnote,
          fta_intro: scheme.fta_intro,
        },
        relationships: {
          rules: {
            data: [
              {
                id: rules[0].id_rule.to_s,
                type: :rules_of_origin_rule,
              },
              {
                id: rules[1].id_rule.to_s,
                type: :rules_of_origin_rule,
              },
              {
                id: rules[2].id_rule.to_s,
                type: :rules_of_origin_rule,
              },
            ],
          },
        },
      },
      included: [
        {
          id: rules[0].id_rule.to_s,
          type: :rules_of_origin_rule,
          attributes: {
            id_rule: rules[0].id_rule,
            heading: rules[0].heading,
            description: rules[0].description,
            rule: rules[0].rule,
          },
        },
        {
          id: rules[1].id_rule.to_s,
          type: :rules_of_origin_rule,
          attributes: {
            id_rule: rules[1].id_rule,
            heading: rules[1].heading,
            description: rules[1].description,
            rule: rules[1].rule,
          },
        },
        {
          id: rules[2].id_rule.to_s,
          type: :rules_of_origin_rule,
          attributes: {
            id_rule: rules[2].id_rule,
            heading: rules[2].heading,
            description: rules[2].description,
            rule: rules[2].rule,
          },
        },
      ],
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to eql expected }
  end
end
