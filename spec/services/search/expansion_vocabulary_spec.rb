# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ExpansionVocabulary do
  before do
    described_class.reset!
    allow(described_class).to receive_messages(worker_process?: false, refresh_delay: 0)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
  end

  after { described_class.reset! }

  def join_refresh
    described_class.instance_variable_get(:@refresh_thread)&.join
  end

  it 'publishes a snapshot from the background refresh' do
    allow(described_class).to receive(:build).and_return(Set['poultry'])

    expect(described_class.supported_words(%w[poultry])).to be_nil

    join_refresh

    expect(described_class.supported_words(%w[poultry])).to eq(Set['poultry'])
    expect(described_class.instance_variable_get(:@refreshing)).to be false
  end

  it 'clears the refresh flag when the build fails' do
    allow(described_class).to receive(:build).and_raise(StandardError, 'db down')

    described_class.supported_words(%w[poultry])
    join_refresh

    expect(described_class.instance_variable_get(:@refreshing)).to be false
    expect(described_class.instance_variable_get(:@snapshot)).to be_nil
  end

  it 'refreshes a stale snapshot in the background and keeps the old words' do
    described_class.remember!(%w[poultry])
    snapshot = described_class.instance_variable_get(:@snapshot)
    described_class.instance_variable_set(
      :@snapshot,
      described_class::Snapshot.new(key: snapshot.key, words: snapshot.words, loaded_at: 2.hours.ago),
    )
    allow(described_class).to receive(:build).and_return(Set['meat'])

    expect(described_class.supported_words(%w[poultry])).to eq(Set['poultry'])

    join_refresh

    expect(described_class.supported_words(%w[meat])).to eq(Set['meat'])
  end

  it 'reads through the reader connection when one is configured' do
    database = Sequel::Model.db
    allow(database).to receive(:servers).and_return({ reader: {} })
    allow(database).to receive(:with_server).and_yield
    allow(Sequel::Model).to receive(:db).and_return(database)
    allow(described_class).to receive(:build).and_return(Set.new)

    described_class.supported_words(%w[poultry])
    join_refresh

    expect(database).to have_received(:with_server).with(:reader)
  end
end
