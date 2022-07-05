RSpec.describe Api::V2::RulesOfOrigin::V2::RuleSerializer do
  subject { serializer.serializable_hash }

  let(:rule) { build :rules_of_origin_v2_rule }
  let(:serializer) { described_class.new rule }

  let :expected do
    {
      data: {
        id: rule.id.to_s,
        type: :rules_of_origin_v2_rule,
        attributes: {
          rule: rule.rule,
          original: rule.original,
          rule_class: rule.rule_class,
          operator: rule.operator,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to eql expected }
  end
end
