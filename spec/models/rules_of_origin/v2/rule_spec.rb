RSpec.describe RulesOfOrigin::V2::Rule do
  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :rule }
  it { is_expected.to respond_to :original }
  it { is_expected.to respond_to :rule_class }
  it { is_expected.to respond_to :operator }
  it { is_expected.to respond_to :footnotes }

  describe '#rule_class' do
    subject { described_class.new(class: rule_class).rule_class }

    context 'without rule class' do
      let(:rule_class) { nil }

      it { is_expected.to be_empty }
    end

    context 'with blank rule class' do
      let(:rule_class) { '' }

      it { is_expected.to be_empty }
    end

    context 'with single rule class' do
      let(:rule_class) { 'AB' }

      it { is_expected.to eql %w[AB] }
    end

    context 'with multiple rule classes' do
      let(:rule_class) { %w[AB CD] }

      it { is_expected.to eql %w[AB CD] }
    end

    context 'with out of order rule classes' do
      let(:rule_class) { %w[CD AB] }

      it { is_expected.to eql %w[AB CD] }
    end
  end

  describe '#footnotes' do
    subject { described_class.new(footnotes:, rule_set:).footnotes }

    let(:rule_set) { instance_double RulesOfOrigin::V2::RuleSet, footnote_definitions: }

    let :footnote_definitions do
      {
        'one' => 'First footnote',
        'two' => 'Second footnote',
      }
    end

    context 'with blank footnotes' do
      let(:footnotes) { '' }

      it { is_expected.to be_empty }
    end

    context 'without footnotes' do
      let(:footnotes) { nil }

      it { is_expected.to be_empty }
    end

    context 'with single footnote' do
      let(:footnotes) { 'one' }

      it { is_expected.to eq [footnote_definitions['one']] }
    end

    context 'with array of footnotes' do
      let(:footnotes) { %w[one two] }

      it { is_expected.to eq footnote_definitions.values }
    end

    context 'with unknown footnote' do
      let(:footnotes) { %w[one three] }

      it { is_expected.to eq [footnote_definitions['one']] }
    end
  end
end
