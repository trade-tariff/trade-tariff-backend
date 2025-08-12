module EnquiryForm::SubmissionHelper
  # Exlude O and I as they're usually avoided in GOV.UK reference numbers
  CHARSET = ('A'..'Z').to_a + (0..9).to_a.map(&:to_s) - %w[O I]

  def create_reference_number(length = 8)
    CHARSET.sample(length).join
  end
end
