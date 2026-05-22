RSpec.describe SearchExpansionDecisionService do
  subject(:decision) { described_class.call(query: query, results: results, request_id: 'req-1') }

  let(:query) { 'laptop' }
  let(:results) do
    [
      build_result(score: 12.5),
      build_result(score: 8.0),
      build_result(score: 7.0),
      build_result(score: 6.0),
      build_result(score: 5.5),
    ]
  end

  before do
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(Search::Instrumentation).to receive(:query_expansion_decided).and_call_original
  end

  context 'when expansion is disabled' do
    before do
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(false)
    end

    it 'does not expand' do
      expect(decision.expand?).to be(false)
      expect(decision.reason).to eq('disabled')
    end
  end

  context 'when conditional expansion is disabled' do
    before do
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    end

    it 'preserves the existing always-expand behaviour' do
      expect(decision.expand?).to be(true)
      expect(decision.reason).to eq('always_enabled')
    end
  end

  context 'when conditional expansion is enabled' do
    before do
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(true)
      allow(AdminConfiguration).to receive(:integer_value).with('expand_search_min_results').and_return(5)
      allow(AdminConfiguration).to receive(:integer_value).with('expand_search_min_score').and_return(5)
    end

    it 'expands acronym-like query tokens' do
      result = described_class.call(query: 'CBD oil', results: results, request_id: 'req-1')

      expect(result.expand?).to be(true)
      expect(result.reason).to eq('non_word_token')
    end

    it 'expands when result count is below the configured threshold' do
      result = described_class.call(query: 'laptop', results: [build_result(score: 12.5)], request_id: 'req-1')

      expect(result.expand?).to be(true)
      expect(result.reason).to eq('low_result_count')
    end

    it 'expands when the maximum score is below the configured threshold' do
      result = described_class.call(
        query: 'laptop',
        results: [build_result(score: 2.5), build_result(score: 1.2), build_result(score: nil), build_result(score: 0.5), build_result(score: 0.4)],
        request_id: 'req-1',
      )

      expect(result.expand?).to be(true)
      expect(result.reason).to eq('low_max_score')
    end

    it 'expands when the tagger finds no useful word parts' do
      result = described_class.call(
        query: 'of the',
        results: results,
        request_id: 'req-1',
      )

      expect(result.expand?).to be(true)
      expect(result.reason).to eq('no_significant_word_parts')
    end

    it 'does not expand when query and results look strong enough' do
      expect(decision.expand?).to be(false)
      expect(decision.reason).to eq('sufficient_results')
    end

    it 'instruments the expansion decision' do
      decision

      expect(Search::Instrumentation).to have_received(:query_expansion_decided).with(
        request_id: 'req-1',
        query: 'laptop',
        expand: false,
        reason: 'sufficient_results',
        result_count: 5,
        max_score: 12.5,
      )
    end
  end

  def build_result(score:)
    GoodsNomenclatureResult.new(
      id: 1,
      goods_nomenclature_item_id: '0101210000',
      goods_nomenclature_sid: 1,
      producline_suffix: '80',
      goods_nomenclature_class: 'Commodity',
      description: 'pure-bred breeding horses',
      formatted_description: 'Pure-bred breeding horses',
      self_text: nil,
      classification_description: nil,
      full_description: nil,
      heading_description: nil,
      declarable: true,
      score: score,
      confidence: nil,
    )
  end
end
