# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      puts "Updating ActionLog subscribe/unsubscribe actions"

      subscribed_action_logs = PublicUsers::ActionLog.where(action: 'subscribed')

      subscribed_action_logs.each { |subscribed_action_log| subscribed_action_log.update(action: 'subscribed stop_press') }
        
      unsubscribed_action_logs = PublicUsers::ActionLog.where(action: 'unsubscribed')

      unsubscribed_action_logs.each { |unsubscribed_action_log| unsubscribed_action_log.update(action: 'unsubscribed stop_press') }

      puts "Completed updating ActionLog subscribe/unsubscribe actions"
    end
  end

  down do
    if TradeTariffBackend.uk?
      puts "Updating ActionLog subscribe/unsubscribe actions"

      subscribed_action_logs = PublicUsers::ActionLog.where(action: 'subscribed stop_press')

      subscribed_action_logs.each { |subscribed_action_log| subscribed_action_log.update(action: 'subscribed') }
        
      unsubscribed_action_logs = PublicUsers::ActionLog.where(action: 'unsubscribed stop_press')

      unsubscribed_action_logs.each { |unsubscribed_action_log| unsubscribed_action_log.update(action: 'unsubscribed') }

      puts "Completed updating ActionLog subscribe/unsubscribe actions"
    end
  end
end
