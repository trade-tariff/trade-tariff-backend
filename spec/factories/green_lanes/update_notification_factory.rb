FactoryBot.define do
  factory :update_notification, class: 'GreenLanes::UpdateNotification' do
    transient do
      measure { nil }
    end
    regulation { measure&.generating_regulation || create(:base_regulation) }
    measure_type { measure&.measure_type || create(:measure_type) }
    status { 0 }
  end
end
