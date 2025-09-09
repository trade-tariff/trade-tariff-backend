FactoryBot.define do
  factory :public_user, class: 'PublicUsers::User' do
    external_id { SecureRandom.uuid }

    transient do
      chapters { nil }
    end

    trait :with_active_stop_press_subscription do
      after(:create) do |user, _evaluator|
        user.stop_press_subscription = true
      end
    end

    trait :with_inactive_stop_press_subscription do
      after(:create) do |user, _evaluator|
        user.stop_press_subscription = false
      end
    end

    trait :with_chapters_preference do
      after(:create) do |user, evaluator|
        user.preferences.update(chapter_ids: evaluator.chapters)
      end
    end

    trait :has_been_soft_deleted do
      after(:create) do |user, _evaluator|
        user.soft_delete!
      end
    end

    trait :with_commodity_codes do
      transient do
        commodity_codes { [] }
      end

      after(:create) do |user, evaluator|
        Array(evaluator.commodity_codes).each do |code|
          create(:user_delta_preference, user: user, commodity_code: code)
        end
      end
    end
  end
end
