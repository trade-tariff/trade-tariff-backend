FactoryBot.define do
  factory :bulk_search, class: 'BulkSearch::Search' do
    input_description { 'foo' }
    ancestor_digits { 6 }
    search_result_ancestors do
      [
        build(:bulk_search_ancestor),
      ]
    end
  end
end
