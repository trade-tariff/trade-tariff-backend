class ChiefCdsGuidanceChangeNotificationService
  def initialize(new_guidance, existing_guidance)
    @new_guidance = new_guidance
    @existing_guidance = existing_guidance
  end

  def call
    new_guidance_keys = new_guidance.keys
    existing_guidance_keys = existing_guidance.keys

    added_keys = new_guidance_keys - existing_guidance_keys
    removed_keys = existing_guidance_keys - new_guidance_keys
    unchanged_keys = existing_guidance_keys & new_guidance_keys
    content_changed_keys = unchanged_keys.reject do |key|
      new_guidance[key] == existing_guidance[key]
    end

    slack_message = 'Chief CDS Guidance has been hot refreshed. </br>'
    slack_message += "Added: #{added_keys.join(', ')} </br>" if added_keys.present?
    slack_message += "Removed: #{removed_keys.join(', ')} </br>" if removed_keys.present?
    slack_message += "Content changed: #{content_changed_keys.join(', ')}" if content_changed_keys.present?

    SlackNotifierService.call(slack_message)
  end

  private

  attr_reader :new_guidance, :existing_guidance
end
