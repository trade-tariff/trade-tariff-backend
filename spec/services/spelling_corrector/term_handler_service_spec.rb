RSpec.describe SpellingCorrector::TermHandlerService do
  describe '#call' do
    subject(:result) { described_class.new(term).call }

    context 'when the term includes mixed casing' do
      let(:term) { 'HeLlo' }

      it { is_expected.to eq('hello') }
    end

    context 'when the term has any digit chars in it' do
      let(:term) { '10-HeLlo' }

      it { is_expected.to be_nil }
    end

    context 'when the term is shorter than 3 chars' do
      let(:term) { 'oF' }

      it { is_expected.to be_nil }
    end
  end
end
