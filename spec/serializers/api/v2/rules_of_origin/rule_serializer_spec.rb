RSpec.describe Api::V2::RulesOfOrigin::RuleSerializer do
  subject(:serializable) { described_class.new(rule).serializable_hash }

  let :rule do
    RulesOfOrigin::Rule.new \
      id_rule: 1,
      heading: 'Heading 1',
      description: 'The description',
      rule: 'The rule',
      alternate_rule: 'or something else'
  end

  let :expected do
    {
      data: {
        id: '1',
        type: :rules_of_origin_rule,
        attributes: {
          id_rule: 1,
          heading: 'Heading 1',
          description: 'The description',
          rule: 'The rule',
          alternate_rule: 'or something else',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql expected
    end
  end
end
