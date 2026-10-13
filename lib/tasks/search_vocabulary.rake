# frozen_string_literal: true

namespace :search_vocabulary do
  desc <<~DESC
    Publish the search expansion vocabulary generation for this service.
    DATE=YYYY-MM-DD selects an explicit effective date for initial
    publication or backfill. The default is the current date.
  DESC
  task publish: :environment do
    date_string = ENV['DATE'].presence
    date = date_string && Date.parse(date_string)
    result = Search::ExpansionVocabularyPublisher.call(date:)

    puts "search_vocabulary:publish status=#{result.status} " \
         "generation=#{result.generation.inspect} word_count=#{result.word_count.inspect} " \
         "reason=#{result.reason.inspect}"
    exit 1 unless result.published?
  end
end
