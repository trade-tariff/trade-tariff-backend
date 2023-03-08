RSpec.describe SearchNegationService do
  describe '#call' do
    shared_examples 'a service which removes negation' do |text, expected|
      it 'removes negation' do
        expect(described_class.new(text).call).to eq(expected)
      end
    end

    it_behaves_like 'a service which removes negation', 'some text, not other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, neither other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, other than other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, excluding other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, except other text', 'some text'

    context 'when text does not contain negation' do
      let(:text) { 'some text' }

      it { expect(described_class.new(text).call).to eq('some text') }
    end

    context 'when text contains negation but no comma' do
      let(:text) { 'some text not other text' }

      it { expect(described_class.new(text).call).to eq('some text not other text') }
    end

    context 'when there is a non-breaking space' do
      let(:text) { "I have a\u00A0non-breaking space" }

      it { expect(described_class.new(text).call).to eq('I have a non-breaking space') }
    end

    context 'when there are multiple negations over multiple lines' do
      let(:text) do
        "some text, not other text.\nsome text, other than other text."
      end

      it { expect(described_class.new(text).call).to eq("some text\nsome text") }
    end

    context 'when a nil value is passed' do
      let(:text) { nil }

      it { expect(described_class.new(text).call).to eq('') }
    end
  end
end
