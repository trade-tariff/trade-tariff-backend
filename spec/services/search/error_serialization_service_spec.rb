RSpec.describe Api::Search::ErrorSerializationService do
  describe '#call' do
    subject(:result) { described_class.new(searches).call }

    context 'with errors' do
      let(:searches) { [BulkSearch::Search.new.tap(&:valid?)] }

      let(:error_response) do
        {
          errors: [
            {
              status: 422,
              title: ' is not a valid number of digits',
              detail: 'Number of digits  is not a valid number of digits',
              source: { pointer: '/data/attributes/number_of_digits' },
            },
            {
              status: 422,
              title: "can't be blank",
              detail: "Input description can't be blank",
              source: { pointer: '/data/attributes/input_description' },
            },
          ],
        }
      end

      it { is_expected.to eq(error_response) }
    end

    context 'without errors' do
      let(:searches) { [BulkSearch::Search.new] }

      it { is_expected.to eq(errors: []) }
    end
  end
end
