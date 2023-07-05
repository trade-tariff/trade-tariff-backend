FactoryBot.define do
  factory :bulk_search_ancestor, class: 'BulkSearch::SearchResult' do
    short_code { '851821' }
    goods_nomenclature_item_id { '8518210000' }
    description { 'Other equipment for wireless networks' }
    producline_suffix { '80' }
    goods_nomenclature_class { 'C' }
    declarable { true }
    score { 0.5 }
    reason { 'matching_digit_ancestor' }
  end
end
