RSpec.describe Api::V2::RulesOfOrigin::V2::RuleSetSerializer do
  subject(:serialized) { serializer.serializable_hash }

  let(:rule_set) { build :rules_of_origin_v2_rule_set }
  let(:serializer) { described_class.new rule_set, rule_count: 2 }

  let :expected do
    {
      data: {
        id: rule_set.id.to_s,
        type: :rules_of_origin_rule_set,
        attributes: {
          heading: rule_set.heading,
          subdivision: rule_set.subdivision,
        },
        relationships: {
          rules: {
            data: [
              {
                id: rule_set.rules.first.id,
                type: :rules_of_origin_v2_rule,
              },
              {
                id: rule_set.rules.second.id,
                type: :rules_of_origin_v2_rule,
              },
            ],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to eql expected }
  end
end
