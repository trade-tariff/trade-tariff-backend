RSpec.describe SearchValidator do
  describe 'validations' do
    shared_examples_for 'a valid search' do |code, type, description|
      subject(:search_validator) do
        described_class.new(
          code:,
          type:,
          description:,
        )
      end

      it { is_expected.to be_valid }
    end

    shared_examples_for 'an invalid search' do |code, type, description|
      subject(:search_validator) do
        described_class.new(
          code:,
          type:,
          description:,
        )
      end

      it { is_expected.not_to be_valid }
    end

    it_behaves_like 'a valid search', '123456', 'RN', ''
    it_behaves_like 'a valid search', '123456', 'RN', 'description'
    it_behaves_like 'a valid search', '', '', 'description'

    it_behaves_like 'an invalid search', '', 'RN', ''
    it_behaves_like 'an invalid search', '123456', '', ''
    it_behaves_like 'an invalid search', '', '', ''
  end
end
