RSpec.describe Api::Beta::InterceptMessageSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { Beta::Search::InterceptMessage.build('plasti') }

    let(:expected) do
      {
        data: {
          id: '9798b947790cd77dec021f882e7b3e29',
          type: :intercept_message,
          attributes: {
            term: 'plasti',
            message: 'Based on your search term, we believe you are looking for plastics which belong in chapter 39.',
            formatted_message: 'Based on your search term, we believe you are looking for plastics which belong in (chapter 39)[/chapters/39].',
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
