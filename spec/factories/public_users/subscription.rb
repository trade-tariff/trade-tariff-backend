FactoryBot.define do
  factory :user_subscription, class: 'PublicUsers::Subscription' do
    user_id { create(:public_user).id }
    subscription_type_id { create(:subscription_type).id }
    active { true }
    email { true }

    after(:build) do |subscription, evaluator|
      # Only set default metadata if none is explicitly provided (including nil)
      if evaluator.__override_names__.include?(:metadata)
        subscription.metadata = Sequel.pg_jsonb(evaluator.metadata) if evaluator.metadata
      else
        subscription.metadata = Sequel.pg_jsonb({
          commodity_codes: %w[1234567890 1234567891 9999999999],
          measures: %w[1234567892],
          chapters: %w[01 99],
        })
      end
    end
  end
end
