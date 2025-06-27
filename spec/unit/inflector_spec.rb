RSpec.describe 'ActiveSupport::Inflector' do
  describe '#pluralize' do
    it { expect('rule_of_origin'.pluralize).to eq 'rules_of_origin' }
    it { expect('rules_of_origin'.pluralize).to eq 'rules_of_origin' }
    it { expect('RuleOfOrigin'.pluralize).to eq 'RulesOfOrigin' }
    it { expect('RulesOfOrigin'.pluralize).to eq 'RulesOfOrigin' }
  end

  describe '#singularize' do
    it { expect('rule_of_origin'.singularize).to eq 'rule_of_origin' }
    it { expect('rules_of_origin'.singularize).to eq 'rule_of_origin' }
    it { expect('RuleOfOrigin'.singularize).to eq 'RuleOfOrigin' }
    it { expect('RulesOfOrigin'.singularize).to eq 'RuleOfOrigin' }
  end
end
