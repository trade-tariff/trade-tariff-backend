FactoryBot.define do
  factory :response, class: 'TariffSynchronizer::Response' do
    response_code { [200, 404, 403].sample }
    content { Forgery(:basic).text }

    trait :success do
      response_code { 200 }
    end

    trait :not_found do
      response_code { 404 }
      content { nil }
    end

    trait :failed do
      response_code { 403 }
      content { nil }
    end

    trait :blank do
      success
      content { '' }
    end

    trait :retry_exceeded do
      failed
      after(:build, &:retry_count_exceeded!)
    end

    initialize_with { new(response_code, content) }
  end
end
