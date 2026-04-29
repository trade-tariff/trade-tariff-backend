RSpec.describe SpellingCorrector::Loaders::Intercepts do
  describe '#load' do
    subject(:load) { described_class.new.load }

    let(:expected_terms) do
      {
        'accelerometer' => 1,
        'accessories' => 13,
        'acessories' => 1,
        'accessaries' => 1,
        'accesrise' => 1,
      }
    end

    it { is_expected.to include(expected_terms) }

    context 'with description intercept records' do
      before do
        create(:description_intercept, term: 'guided bicycles')
      end

      it { is_expected.to include('guided' => 1, 'bicycles' => 1) }
    end
  end
end
