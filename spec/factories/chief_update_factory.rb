FactoryBot.define do
  factory :chief_update, parent: :base_update, class: 'TariffSynchronizer::ChiefUpdate' do
    filename { TariffSynchronizer::ChiefFileNameGenerator.new(example_date).name }
    update_type { 'TariffSynchronizer::ChiefUpdate' }
  end
end
