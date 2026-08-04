FactoryBot.define do
  factory :evaluation_experiment do
    name { "experiment_#{SecureRandom.hex(4)}" }
    configuration_overrides { {} }
    default_scope { {} }
  end
end
