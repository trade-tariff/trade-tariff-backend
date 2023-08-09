RSpec.describe SearchDescriptionNormaliserService do
  describe '#call' do
    subject(:call) { described_class.new(description).call }

    shared_examples 'a normalised description' do |description, expected|
      let(:description) { description }

      it { is_expected.to eq expected }
    end

    it_behaves_like 'a normalised description', 'DescRiption', 'description' # downcases
    it_behaves_like 'a normalised description', 'Description   with spaces and 123  ', 'description with spaces and 123' # removes extra spaces
    it_behaves_like 'a normalised description', 'a bunch of the stop words', 'a bunch of the stop words' # does not remove stop words in phrases
    it_behaves_like 'a normalised description', 'spr', 'spr' # does not remove three letter words
    it_behaves_like 'a normalised description', 'and', '' # removes stop words
    it_behaves_like 'a normalised description', 'the', '' # removes stop words
    it_behaves_like 'a normalised description', 'ti', '' # removes words shorter than 3 chars
    it_behaves_like 'a normalised description', nil, '' # coerces nil to string
    it_behaves_like 'a normalised description', '', '' # does nothing to an empty string
  end
end
