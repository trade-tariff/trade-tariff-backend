RSpec.describe 'search metrics initializer' do
  subject(:source) { Rails.root.join('config/initializers/search_metrics.rb').read }

  it 'subscribes after boot so a migration task can load the environment' do
    expect(source).to include('to_prepare')
    expect(source).not_to match(/^Search::/)
  end
end
