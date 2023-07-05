FactoryBot.define do
  factory :bulk_search_result, class: 'BulkSearch::SearchResult' do
    number_of_digits { 6 }
    short_code { '851821' }
    score { 0.5 }
  end
end
