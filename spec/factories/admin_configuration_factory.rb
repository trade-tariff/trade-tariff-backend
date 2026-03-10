FactoryBot.define do
  factory :admin_configuration do
    name { "test_config_#{SecureRandom.hex(4)}" }
    value { 'test value' }
    config_type { 'string' }
    area { 'classification' }
    description { 'A test configuration' }

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

    trait :nested_options do
      config_type { 'nested_options' }
      value do
        {
          'selected' => 'gpt-5.2',
          'sub_values' => { 'reasoning_effort' => 'low' },
          'options' => [
            { 'key' => 'gpt-5.2', 'label' => 'GPT-5.2 (latest flagship)', 'sub_options' => { 'reasoning_effort' => %w[none low medium high] } },
            { 'key' => 'gpt-4.1-2025-04-14', 'label' => 'GPT-4.1 (1M context)', 'sub_options' => {} },
          ],
        }
      end
    end
  end
end
