class EnquiryForm::Submission < Sequel::Model(Sequel[:enquiry_form_submissions].qualify(:public))
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  # Exlude O and I as they're usually avoided in GOV.UK reference numbers
  CHARSET = ('A'..'Z').to_a + (0..9).to_a.map(&:to_s) - %w[O I]

  def before_validation
    super

    self.reference_number ||= create_reference_number
    self.email_status ||= 'Pending'
  end

  def validate
    super

    validates_includes %w[Pending Sent Failed], :email_status
  end

  def before_save
    super

    set_submitted_at_timestamp if email_status_changed_to_sent?
  end

  private

  def create_reference_number(length = 8)
    loop do
      reference_number = CHARSET.sample(length).join

      # returns nil if no record
      unless EnquiryForm::Submission.where(reference_number: reference_number).first
        return reference_number
      end
    end
  end

  def email_status_changed_to_sent?
    email_status == 'Sent' && changed_columns.include?(:email_status)
  end

  def set_submitted_at_timestamp
    self.submitted_at ||= Time.zone.now
  end
end
