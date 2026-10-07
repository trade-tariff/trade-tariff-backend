require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::ConfigurationsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:make_request) { authenticated_get api_admin_search_evaluation_configuration_path(format: :json) }

  describe 'GET #show' do
    it { is_expected.to have_http_status :success }

    it 'returns the baseline and allowed_overrides keys' do
      api_response
      expect(json_response).to include('baseline', 'allowed_overrides')
    end

    it 'returns exactly the 9 baseline keys with a real backend source' do
      api_response
      expect(json_response['baseline'].keys).to contain_exactly(
        'rrf_k', 'vector_score_threshold', 'vector_ef_search', 'search_non_declarables',
        'search_compressed_notes_enabled', 'search_general_rules_enabled',
        'candidate_limit', 'max_rounds', 'question_model'
      )
    end

    it 'returns exactly the 10 allowed override keys, each with its own type metadata' do
      api_response
      expect(json_response['allowed_overrides'].map { |o| o['name'] }).to contain_exactly(
        'question_model', 'simulator_model', 'candidate_limit', 'max_rounds', 'rrf_k',
        'vector_score_threshold', 'vector_ef_search', 'search_non_declarables',
        'search_compressed_notes_enabled', 'search_general_rules_enabled'
      )
    end

    it 'describes each allowed override with its type' do
      overrides = json_response['allowed_overrides']

      expect(overrides.map { |o| o['name'] }).to include('question_model', 'candidate_limit', 'search_non_declarables')
      expect(overrides.find { |o| o['name'] == 'question_model' }['config_type']).to eq('options')
      expect(overrides.find { |o| o['name'] == 'candidate_limit' }).to include('config_type' => 'integer', 'min' => 1, 'max' => 250)
      expect(overrides.find { |o| o['name'] == 'search_non_declarables' }).to include('name' => 'search_non_declarables', 'config_type' => 'boolean')
    end

    it 'includes a plain-language description for every allowed override' do
      overrides = json_response['allowed_overrides']

      overrides.each do |override|
        expect(override['description']).to be_present, "#{override['name']} has no description"
      end
    end
  end
end
