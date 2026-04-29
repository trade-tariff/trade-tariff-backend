# frozen_string_literal: true

# The aws-actionmailer-ses gem's SESV2::Mailer#to_addresses passes
# message.to directly to the AWS SES v2 API, which requires an Array.
# The mail gem normalises a single recipient address to a plain String,
# so any mailer with exactly one To: address raises:
#
#   ArgumentError: expected params[:destination][:to_addresses] to be
#   an Array, got class String instead
#
# Wrapping the return value in Array() coerces both cases safely:
#   Array("a@b.com")          # => ["a@b.com"]
#   Array(["a@b.com","c@d"]) # => ["a@b.com", "c@d"]
#   Array(nil)                # => []
Aws::ActionMailer::SESV2::Mailer.prepend(
  Module.new do
    private

    def to_addresses(message)
      Array(super)
    end
  end,
)
