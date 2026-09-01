class EnquiryForm::Submission < Data.define(:form_data)
  HMRC_AUDIENCE = 'hmrc'.freeze
  TRADE_TARIFF_AUDIENCE = 'trade_tariff'.freeze
  HMRC_AUDIENCES = [HMRC_AUDIENCE].freeze
  FLAGGED_AUDIENCES = [HMRC_AUDIENCE, TRADE_TARIFF_AUDIENCE].freeze
  TEAM_REDACTED_FIELDS = %i[name email].freeze

  Delivery = Data.define(:audience, :recipient, :form_data, :test_condition)

  def self.from(form_data)
    new(form_data: form_data.to_h.symbolize_keys.freeze)
  end

  def to_h
    form_data
  end

  def test_condition
    form_data[:test_condition].presence || 'none'
  end

  def feature_flagged?
    test_condition != 'none'
  end

  def audiences
    feature_flagged? ? FLAGGED_AUDIENCES : HMRC_AUDIENCES
  end

  def delivery_for(audience)
    case audience
    when HMRC_AUDIENCE
      Delivery.new(audience:, recipient: ENV['ENQUIRY_FORM_EMAIL'], form_data:, test_condition:)
    when TRADE_TARIFF_AUDIENCE
      return unless feature_flagged?

      Delivery.new(
        audience:,
        recipient: trade_tariff_recipient,
        form_data: form_data.except(*TEAM_REDACTED_FIELDS),
        test_condition:,
      )
    else
      raise ArgumentError, "Unknown enquiry email audience: #{audience}"
    end
  end

private

  def trade_tariff_recipient
    Mail::Address.new(TradeTariffBackend.support_email).address
  end
end
