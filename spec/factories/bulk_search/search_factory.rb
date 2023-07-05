FactoryBot.define do
  factory :bulk_search, class: 'BulkSearch::Search' do
    input_description { 'foo' }
    number_of_digits { 6 }
    search_results do
      [
        build(:bulk_search_result, number_of_digits:),
      ]
    end
  end
end
