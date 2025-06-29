RSpec.describe RulesOfOrigin::Rule do
  describe 'attributes' do
    it { is_expected.to respond_to :id_rule }
    it { is_expected.to respond_to :scheme_code }
    it { is_expected.to respond_to :heading }
    it { is_expected.to respond_to :description }
    it { is_expected.to respond_to :quota_amount }
    it { is_expected.to respond_to :quota_unit }
    it { is_expected.to respond_to :rule }
    it { is_expected.to respond_to :alternate_rule }
  end

  describe '.new' do
    subject { described_class.new attrs }

    let(:attrs) { attributes_for(:rules_of_origin_rule) }

    it { is_expected.to have_attributes id_rule: attrs[:id_rule] }
    it { is_expected.to have_attributes scheme_code: attrs[:scheme_code] }
    it { is_expected.to have_attributes heading: attrs[:heading] }
    it { is_expected.to have_attributes description: attrs[:description] }
    it { is_expected.to have_attributes quota_amount: attrs[:quota_amount] }
    it { is_expected.to have_attributes quota_unit: attrs[:quota_unit] }
    it { is_expected.to have_attributes rule: attrs[:rule] }
    it { is_expected.to have_attributes alternate_rule: attrs[:alternate_rule] }
  end

  describe '#==' do
    subject(:rule) { build :rules_of_origin_rule }

    let(:matching) { build :rules_of_origin_rule, id_rule: rule.id_rule }
    let(:different) { build :rules_of_origin_rule }

    it { is_expected.to eq matching }
    it { is_expected.not_to eq different }
  end
end
