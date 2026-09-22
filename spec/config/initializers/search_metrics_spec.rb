RSpec.describe 'search metrics initializer' do
  it 'subscribes after boot and does not resolve Search while the file loads' do
    callbacks = []
    allow(Rails.env).to receive(:test?).and_return(false)
    allow(Rails.application.config).to receive(:to_prepare) { |&block| callbacks << block }
    calls = 0
    allow(Search::Metrics).to receive(:subscribe!) { calls += 1 }

    load Rails.root.join('config/initializers/search_metrics.rb')

    expect(calls).to eq(0)
    expect(callbacks.size).to eq(1)
    callbacks.first.call
    expect(calls).to eq(1)
  end
end
