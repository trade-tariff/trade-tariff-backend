RSpec.describe RulesOfOrigin::V2::RuleSet do
  subject { described_class.new scheme: }

  let(:scheme) { build :rules_of_origin_scheme }

  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :scheme }
  it { is_expected.to respond_to :heading }
  it { is_expected.to respond_to :subdivision }
  it { is_expected.to respond_to :prefix }
  it { is_expected.to respond_to :min }
  it { is_expected.to respond_to :max }
  it { is_expected.to respond_to :valid }
  it { is_expected.to respond_to :rules }

  describe '.build_for_scheme' do
    subject { described_class.build_for_scheme scheme, rule_set_data }

    let :rule_set_data do
      { 'rule_sets' => attributes_for_list(:rules_of_origin_v2_rule_set, 2) }
    end

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of described_class }

    context 'with footnote_definitions' do
      let :rule_set_data do
        {
          'rule_sets' => attributes_for_list(:rules_of_origin_v2_rule_set, 2),
          'footnotes' => { 'first footnote' => 'This is a footnote' },
        }
      end

      it { is_expected.to all have_attributes footnote_definitions: include('first footnote') }
    end
  end

  describe '#id' do
    subject { build(:rules_of_origin_v2_rule_set).id }

    it { is_expected.to be_present }
  end

  describe '#headings_range' do
    subject(:rule_set) { described_class.new(scheme:, min:, max:).headings_range }

    let(:min) { 10 }
    let(:max) { 20 }

    context 'for valid heading range' do
      it { is_expected.to eql Range.new(10, 20) }
    end

    context 'with string heading range' do
      let(:min) { '0000000010' }
      let(:max) { '0000000020' }

      it { is_expected.to eql Range.new(10, 20) }
    end

    context 'with invalid min' do
      let(:min) { 'foo' }

      it { expect { rule_set }.to raise_exception described_class::InvalidHeadingRange }
    end

    context 'with invalid max' do
      let(:max) { '20foo' }

      it { expect { rule_set }.to raise_exception described_class::InvalidHeadingRange }
    end
  end

  describe '#valid?' do
    subject { described_class.new(scheme:, min:, max:).valid? }

    let(:min) { 10 }
    let(:max) { 20 }

    context 'for valid heading range' do
      it { is_expected.to be true }
    end

    context 'with invalid min' do
      let(:min) { 'foo' }

      it { is_expected.to be false }
    end

    context 'with invalid max' do
      let(:max) { '20foo' }

      it { is_expected.to be false }
    end
  end

  describe '#rules' do
    subject { described_class.new(scheme:, rules: [rule]).rules }

    let(:rule) { attributes_for :rules_of_origin_v2_rule, rule: 'test rule' }

    it { is_expected.to all be_instance_of RulesOfOrigin::V2::Rule }
    it { is_expected.to all have_attributes rule: 'test rule' }
  end

  describe '#for_subheading?' do
    subject { rule_set.for_subheading? subheading_code }

    let :rule_set do
      build :rules_of_origin_v2_rule_set, min: '2000000000', max: '2999999999'
    end

    context 'with 10 digit code in range' do
      let(:subheading_code) { '2000000000' }

      it { is_expected.to be true }
    end

    context 'with 10 digit code at end of range' do
      let(:subheading_code) { '2999999999' }

      it { is_expected.to be true }
    end

    context 'with 10 digit code out of range' do
      let(:subheading_code) { '3000000000' }

      it { is_expected.to be false }
    end

    context 'with short code in range' do
      let(:subheading_code) { '202020' }

      it { is_expected.to be true }
    end

    context 'with short code out of range' do
      let(:subheading_code) { '3000' }

      it { is_expected.to be false }
    end
  end

  describe '#subdivision' do
    subject { described_class.new(subdivision: '').subdivision }

    it { is_expected.to be_nil }
  end
end
