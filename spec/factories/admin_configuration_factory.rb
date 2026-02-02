FactoryBot.define do
  factory :admin_configuration do
    name { "test_config_#{SecureRandom.hex(4)}" }
    value { 'test value' }
    config_type { 'string' }
    area { 'classification' }
    description { 'A test configuration' }
    operation { 'C' }
    operation_date { Time.zone.today }

    trait :markdown do
      config_type { 'markdown' }
      value { "## Heading\n\nBody text" }
    end

    trait :boolean do
      config_type { 'boolean' }
      value { true }
    end

    trait :integer do
      config_type { 'integer' }
      value { 250 }
    end

    trait :options do
      config_type { 'options' }
      value do
        {
          'selected' => 'claude',
          'options' => [
            { 'key' => 'claude', 'label' => 'Claude' },
            { 'key' => 'openai', 'label' => 'OpenAI' },
          ],
        }
      end
    end

    after(:create) do |_config, _evaluator|
      AdminConfiguration.refresh!(concurrently: false) if Rails.env.test?
    end
  end
end
