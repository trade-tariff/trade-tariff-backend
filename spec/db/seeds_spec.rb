RSpec.describe 'db/seeds.rb' do
  it 'refreshes the materialized views' do
    allow(MaterializeViewHelper).to receive(:refresh_materialized_view)

    load Rails.root.join('db/seeds.rb')

    expect(MaterializeViewHelper).to have_received(:refresh_materialized_view)
  end
end
