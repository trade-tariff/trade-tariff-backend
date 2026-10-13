# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'search vocabulary rake tasks' do
  describe 'search_vocabulary:publish' do
    subject(:publish) { Rake::Task['search_vocabulary:publish'].invoke }

    let(:task) { Rake::Task['search_vocabulary:publish'] }
    let(:published) do
      Search::ExpansionVocabularyPublisher::Result.new(
        status: :published, generation: 'abc123', word_count: 2, reason: nil,
      )
    end

    around do |example|
      original_date = ENV.fetch('DATE', nil)
      ENV.delete('DATE')
      example.run
    ensure
      original_date ? ENV['DATE'] = original_date : ENV.delete('DATE')
    end

    after { task.reenable }

    before do
      allow(Search::ExpansionVocabularyPublisher).to receive(:call).and_return(published)
    end

    it 'publishes for the current date by default' do
      expect { publish }.to output(/status=published/).to_stdout

      expect(Search::ExpansionVocabularyPublisher).to have_received(:call).with(date: nil)
    end

    it 'supports an explicit DATE for initial publication or backfill' do
      ENV['DATE'] = '2025-06-01'

      expect { publish }.to output(/status=published/).to_stdout

      expect(Search::ExpansionVocabularyPublisher).to have_received(:call).with(date: Date.parse('2025-06-01'))
    end

    it 'exits with a failure status when publication does not complete' do
      failed = Search::ExpansionVocabularyPublisher::Result.new(
        status: :failed, generation: nil, word_count: nil, reason: 'StandardError: database unavailable',
      )
      allow(Search::ExpansionVocabularyPublisher).to receive(:call).and_return(failed)

      expect { suppress_output { publish } }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end
  end
end
