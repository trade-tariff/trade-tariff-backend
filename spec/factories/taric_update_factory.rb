FactoryBot.define do
  factory :taric_update, parent: :base_update, class: 'TariffSynchronizer::TaricUpdate' do
    issue_date { example_date }
    filename { "#{example_date}_TGB#{example_date.strftime('%y')}#{example_date.yday}.xml" }
    update_type { 'TariffSynchronizer::TaricUpdate' }
  end
end
