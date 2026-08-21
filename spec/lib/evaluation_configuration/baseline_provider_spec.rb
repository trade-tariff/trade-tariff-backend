require 'rails_helper'

RSpec.describe EvaluationConfiguration::BaselineProvider do
  describe '.call' do
    before do
      allow(AdminConfiguration).to receive(:integer_value).and_call_original
      allow(AdminConfiguration).to receive(:integer_value).with('rrf_k').and_return(60)
      allow(AdminConfiguration).to receive(:integer_value).with('vector_score_threshold').and_return(35)
      allow(AdminConfiguration).to receive(:integer_value).with('vector_ef_search').and_return(100)
      allow(AdminConfiguration).to receive(:integer_value).with('opensearch_result_limit').and_return(50)
      allow(AdminConfiguration).to receive(:integer_value).with('interactive_search_max_questions').and_return(7)
      allow(AdminConfiguration).to receive(:enabled?).and_call_original
      allow(AdminConfiguration).to receive(:enabled?).with('search_non_declarables').and_return(false)
      allow(AdminConfiguration).to receive(:enabled?).with('search_compressed_notes_enabled').and_return(false)
      allow(AdminConfiguration).to receive(:enabled?).with('search_general_rules_enabled').and_return(false)
      allow(AdminConfiguration).to receive(:nested_options_value).and_call_original
      allow(AdminConfiguration).to receive(:nested_options_value).with('search_model')
        .and_return(selected: 'gpt-5.4', sub_values: { 'reasoning_effort' => 'medium' })
    end

    it 'maps rrf_k directly from AdminConfiguration' do
      expect(described_class.call['rrf_k']).to eq(60)
    end

    it 'maps vector_score_threshold directly from AdminConfiguration' do
      expect(described_class.call['vector_score_threshold']).to eq(35)
    end

    it 'maps vector_ef_search directly from AdminConfiguration' do
      expect(described_class.call['vector_ef_search']).to eq(100)
    end

    it 'maps search_non_declarables directly from AdminConfiguration' do
      expect(described_class.call['search_non_declarables']).to be(false)
    end

    it 'maps search_compressed_notes_enabled directly from AdminConfiguration' do
      expect(described_class.call['search_compressed_notes_enabled']).to be(false)
    end

    it 'maps search_general_rules_enabled directly from AdminConfiguration' do
      expect(described_class.call['search_general_rules_enabled']).to be(false)
    end

    it 'maps candidate_limit from opensearch_result_limit' do
      expect(described_class.call['candidate_limit']).to eq(50)
    end

    it 'maps max_rounds from interactive_search_max_questions' do
      expect(described_class.call['max_rounds']).to eq(7)
    end

    it 'maps question_model from the selected search_model option' do
      expect(described_class.call['question_model']).to eq('gpt-5.4')
    end

    it 'omits simulator_model entirely, since it has no real backend source' do
      result = described_class.call
      expect(result).not_to have_key('simulator_model')
    end

    it 'returns exactly the 9 keys with a real backend source' do
      expect(described_class.call.keys).to contain_exactly(
        'rrf_k', 'vector_score_threshold', 'vector_ef_search', 'search_non_declarables',
        'search_compressed_notes_enabled', 'search_general_rules_enabled',
        'candidate_limit', 'max_rounds', 'question_model'
      )
    end
  end
end
