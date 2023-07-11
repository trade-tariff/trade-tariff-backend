RSpec.describe BulkSearch::ErrorSerializationService do
  describe '#call' do
    subject(:result) { described_class.new(searches).call }

    let(:searches) { [BulkSearch::Search.new.tap(&:valid?)] }

    context 'with errors' do
      let(:error_response) do
        {
          errors: [
            {
              status: 422,
              title: ' is not a valid number of digits',
              detail: 'Number of digits  is not a valid number of digits',
              source: { pointer: '/data/attributes/number_of_digits' },
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
