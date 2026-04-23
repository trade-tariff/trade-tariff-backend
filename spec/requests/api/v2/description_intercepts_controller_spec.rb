RSpec.describe Api::V2::DescriptionInterceptsController, :v2 do
  describe 'GET #index' do
    let!(:guided_excluded) do
      create(
        :description_intercept,
        term: 'alpha',
        sources: Sequel.pg_array(%w[guided_search], :text),
        message: 'Alpha guidance',
        excluded: true,
        guidance_level: 'warning',
        guidance_location: 'results',
        escalate_to_webchat: true,
      )
    end

    let!(:fpo_excluded) do
      create(
        :description_intercept,
        term: 'beta',
        sources: Sequel.pg_array(%w[fpo_search], :text),
        message: 'Beta guidance',
        excluded: true,
        guidance_level: 'info',
        guidance_location: 'question',
        escalate_to_webchat: false,
      )
    end

    let!(:fpo_included) do
      create(
        :description_intercept,
        term: 'gamma',
        sources: Sequel.pg_array(%w[fpo_search], :text),
        message: 'Gamma guidance',
        excluded: false,
        guidance_level: nil,
        guidance_location: nil,
        escalate_to_webchat: false,
        filter_prefixes: Sequel.pg_array(%w[0201], :text),
      )
    end

    it 'returns all description intercepts ordered by term then id' do
      api_get api_description_intercepts_path

      body = JSON.parse(response.body)

      expect(response).to be_successful
      expect(body.fetch('data').map { |row| row.fetch('id') }).to eq([guided_excluded.id.to_s, fpo_excluded.id.to_s, fpo_included.id.to_s])
      expect(body.fetch('data').first.fetch('attributes').keys).to match_array(%w[
        term
        sources
        message
        excluded
        created_at
        updated_at
        guidance_level
        guidance_location
        escalate_to_webchat
        filter_prefixes
      ])
    end

    it 'filters by source' do
      api_get api_description_intercepts_path, params: { source: 'fpo_search' }

      body = JSON.parse(response.body)

      expect(body.fetch('data').map { |row| row.fetch('id') }).to eq([fpo_excluded.id.to_s, fpo_included.id.to_s])
    end

    it 'filters by excluded=true' do
      api_get api_description_intercepts_path, params: { excluded: true }

      body = JSON.parse(response.body)

      expect(body.fetch('data').map { |row| row.fetch('id') }).to eq([guided_excluded.id.to_s, fpo_excluded.id.to_s])
    end

    it 'filters by excluded=false' do
      api_get api_description_intercepts_path, params: { excluded: false }

      body = JSON.parse(response.body)

      expect(body.fetch('data').map { |row| row.fetch('id') }).to eq([fpo_included.id.to_s])
    end

    it 'combines source and excluded filters' do
      api_get api_description_intercepts_path, params: { source: 'fpo_search', excluded: true }

      body = JSON.parse(response.body)

      expect(body.fetch('data').map { |row| row.fetch('id') }).to eq([fpo_excluded.id.to_s])
    end
  end
end
