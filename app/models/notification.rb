class Notification
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :email,
                :template_id,
                :email_reply_to_id,
                :reference,
                :personalisation

  validates :email,
            presence: true,
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              message: 'must be a valid e-mail address',
            }

  validates :template_id,
            presence: true,
            format: {
              with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
              message: 'must be a valid UUID',
            }

  validates :email_reply_to_id,
            allow_blank: true,
            format: {
              with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
              message: 'must be a valid UUID',
            }

  validates :reference, length: { maximum: 255 }

  validate :personalisation_structure

  def id
    @id ||= SecureRandom.uuid
  end

  def as_json(except: %w[id context_for_validation errors])
    super(except:).with_indifferent_access
  end

  private

  def personalisation_structure
    return unless personalisation.is_a?(Hash)

    personalisation.each_value do |value|
      unless value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass) || value.nil?
        errors.add(:personalisation, 'values must be scalar (String, Numeric, Boolean, nil)')
      end
    end
  end
end
