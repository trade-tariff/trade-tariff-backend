FactoryBot.define do
  factory :live_issue do
    sequence(:title) { |n| "Live Issue #{n}" }
    description { 'This is a description of the issue' }
    suggested_action { 'This is a suggested action on the issue' }
    status { 'Active' }
    date_discovered { Time.zone.today }
    commodities { %w[0101000000 0101000090] }
  end
end
