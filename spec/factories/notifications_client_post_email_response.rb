require 'notifications/client'
FactoryBot.define do
  factory :notifications_client_post_email_response,
          class: Notifications::Client::ResponseNotification do
    body do
      {
        'id' => SecureRandom.uuid,
        'reference' => nil,
        'content' => {
          'body' => 'test',
          'subject' => 'test',
          'from_email' => 'test@example.com',
        },
        'template' => {
          'id' => 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
          'version' => 1,
          'uri' => '/v2/templates/b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        },
        'uri' => '/notifications/aceed36e-6aee-494c-a09f-88b68904bad6',
      }
    end

    initialize_with do
      Notifications::Client::ResponseNotification.new(body)
    end
  end
end
