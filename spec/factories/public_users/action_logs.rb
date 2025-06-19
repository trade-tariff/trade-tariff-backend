FactoryBot.define do
  factory :action_log, class: 'PublicUsers::ActionLog' do
    user { create(:public_user) }
    action { PublicUsers::ActionLog::REGISTERED }
  end
end
