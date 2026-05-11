require 'spec_helper'
require 'json'

RSpec.describe 'canonical V2 OpenAPI artifact' do
  subject(:openapi) { JSON.parse(File.read('swagger/v2/swagger.json')) }

  # This validates the committed artifact during the normal RSpec phase.
  # CI regenerates and self-heals this file later via swagger:generate.

  def path_parameter_names(path)
    openapi.fetch('paths').fetch(path).fetch('parameters', [])
      .select { |parameter| parameter.fetch('in') == 'path' }
      .map { |parameter| parameter.fetch('name') }
  end

  it 'orders paths deterministically' do
    paths = openapi.fetch('paths').keys

    expect(paths).to eq(paths.sort)
  end

  it 'excludes internal-only endpoints' do
    expect(openapi.fetch('paths')).not_to include(
      '/api/chemicals/{id}',
      '/api/news/items/{id}',
      '/api/sections/{id}/chapters',
      '/api/sections/{position}/chapters',
    )
  end

  it 'uses docs-ready path names' do
    expect(openapi.fetch('paths')).to include(
      '/api/sections/{position}',
      '/api/chapters/{chapter_id}',
      '/api/headings/{heading_id}',
      '/api/measures/{measure_sid}',
      '/api/exchange_rates/{year}-{month}',
      '/api/exchange_rates/period_lists/{year}',
    )
  end

  it 'uses docs-ready parameter names', :aggregate_failures do
    expect(path_parameter_names('/api/sections/{position}')).to eq(%w[position])
    expect(path_parameter_names('/api/chapters/{chapter_id}')).to eq(%w[chapter_id])
    expect(path_parameter_names('/api/headings/{heading_id}')).to eq(%w[heading_id])
    expect(path_parameter_names('/api/measures/{measure_sid}')).to eq(%w[measure_sid])
    expect(path_parameter_names('/api/exchange_rates/{year}-{month}')).to eq(%w[year month])
  end

  it 'defines reusable docs metadata' do
    components = openapi.fetch('components')

    expect(components.fetch('parameters')).to include('accept_header')
    expect(components.fetch('schemas')).to include('error_response')
  end

  it 'documents response example coverage' do
    expect(openapi.fetch('info').fetch('x-response-examples')).to include('not yet complete')
  end
end
