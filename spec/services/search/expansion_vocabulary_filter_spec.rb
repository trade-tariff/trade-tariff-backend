RSpec.describe Search::ExpansionVocabularyFilter do
  subject(:result) { described_class.call(original_query: query, added_terms: terms) }

  let(:query) { 'chicken' }
  let(:terms) { ['poultry meat', 'zaptoxidinyl serum'] }
  let(:supported) { Set.new(%w[poultry meat]) }
  let(:lookup) { Search::ExpansionVocabulary::Lookup.new(status: :ready, words: supported, generation: 'test') }

  before { allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(lookup) }

  describe '.call' do
    it 'filters proposals independently', :aggregate_failures do
      expect(result.expanded_query).to eq('chicken poultry meat')
      expect(result.accepted_terms).to eq(['poultry meat'])
      expect(result.rejected_terms).to eq(['zaptoxidinyl serum'])
      expect(result.status).to eq(:ready)
    end

    it 'uses one vocabulary lookup' do
      result

      expect(Search::ExpansionVocabulary).to have_received(:lookup).with(%w[poultry meat zaptoxidinyl serum]).once
    end

    context 'with a comma within one phrase' do
      let(:terms) { ['poultry meat, frozen'] }

      it 'does not split the proposal' do
        expect(result.accepted_terms).to eq([])
        expect(result.rejected_terms).to eq(['poultry meat, frozen'])
      end
    end

    context 'with only original words and stop words' do
      let(:terms) { ['of chicken'] }

      it 'still checks vocabulary readiness' do
        expect(result.accepted_terms).to eq(['of chicken'])
        expect(Search::ExpansionVocabulary).to have_received(:lookup).with([])
      end
    end

    context 'with no proposals' do
      let(:terms) { [] }

      it 'skips vocabulary lookup' do
        expect(result.expanded_query).to eq(query)
        expect(result.status).to eq(:unchanged)
        expect(Search::ExpansionVocabulary).not_to have_received(:lookup)
      end
    end

    context 'with missing vocabulary' do
      let(:lookup) { Search::ExpansionVocabulary::Lookup.new(status: :unavailable, words: Set.new, generation: nil) }

      it 'falls back without flagging search failure', :aggregate_failures do
        expect { result }.not_to change(TradeTariffRequest, :search_failures)
        expect(result.expanded_query).to eq(query)
        expect(result.accepted_terms).to eq([])
        expect(result.status).to eq(:unavailable)
      end

      context 'with only original words' do
        let(:terms) { ['of chicken'] }

        it 'does not bypass readiness' do
          expect(result.expanded_query).to eq(query)
        end
      end
    end

    context 'with ready vocabulary but no support' do
      let(:supported) { Set.new }

      it 'distinguishes no matches from unavailable' do
        expect(result.expanded_query).to eq(query)
        expect(result.status).to eq(:ready)
      end
    end

    context 'with ambiguous plurals' do
      let(:query) { 'cases' }
      let(:terms) { %w[case cas caseses] }
      let(:supported) { Set.new(%w[case]) }

      it 'requires vocabulary evidence' do
        expect(result.accepted_terms).to eq(%w[case])
        expect(result.rejected_terms).to eq(%w[cas caseses])
      end
    end

    context 'with punctuation and internal apostrophes' do
      let(:terms) { ["'poultry' meat", "o'clock"] }
      let(:supported) { Set.new(['poultry', 'meat', "o'clock"]) }

      it 'preserves accepted surface wording' do
        expect(result.accepted_terms).to eq(terms)
      end
    end

    it 'treats a legacy rewrite as one span' do
      result = described_class.call(original_query: query, expanded_query: 'Chicken poultry meat, zaptoxidinyl serum')

      expect(result.expanded_query).to eq(query)
      expect(result.rejected_terms).to eq(['poultry meat, zaptoxidinyl serum'])
    end

    it 'preserves a supported legacy rewrite' do
      result = described_class.call(original_query: query, expanded_query: 'Poultry meat')

      expect(result.expanded_query).to eq('chicken Poultry meat')
      expect(result.accepted_terms).to eq(['Poultry meat'])
    end
  end
end
