FactoryBot.define do
  factory :evaluation_run do
    association :evaluation_experiment, strategy: :create
    status { 'queued' }
    triggered_by { 'operator' }
  end
end
