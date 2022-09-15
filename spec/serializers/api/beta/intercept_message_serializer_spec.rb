RSpec.describe Api::Beta::InterceptMessageSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { Beta::Search::InterceptMessage.build('cherry tomatoes') }

    let(:expected) do
      {
        data: {
          id: 'bc81794bb156f35b54d97d5093f251f5',
          type: :intercept_message,
          attributes: {
            term: 'cherry tomatoes',
            message: 'Please use commodity code 0702000007 for soya cherry tomatoes.',
            formatted_message: 'Please use (commodity code 0702000007)[/commodities/0702000007] for soya cherry tomatoes.',
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
