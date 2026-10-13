# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublishSearchVocabularyWorker do
  subject(:worker) { described_class.new }

  let(:result) do
    Search::ExpansionVocabularyPublisher::Result.new(
      status: :published, generation: 'abc123', word_count: 3, reason: nil,
    )
  end

  before do
    allow(Search::ExpansionVocabularyPublisher).to receive(:call).and_return(result)
    allow(worker.logger).to receive(:info)
  end

  describe '#perform' do
    it 'publishes the current-date generation and logs the outcome' do
      expect(worker.perform).to eq(result)

      expect(Search::ExpansionVocabularyPublisher).to have_received(:call)
      expect(worker.logger).to have_received(:info).with(
        /status=published generation="abc123" word_count=3 reason=nil/,
      )
    end

    it 'logs a skipped run without retrying' do
      skipped = Search::ExpansionVocabularyPublisher::Result.new(
        status: :skipped, generation: nil, word_count: nil, reason: 'publish lock held by another publisher',
      )
      allow(Search::ExpansionVocabularyPublisher).to receive(:call).and_return(skipped)

      worker.perform

      expect(worker.logger).to have_received(:info).with(/status=skipped/)
    end
  end
end
