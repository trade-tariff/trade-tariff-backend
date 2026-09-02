require 'mail'

class EnquiryForm::Submission < Data.define(:form_data, :trusted_context)
  HMRC_AUDIENCE = 'hmrc'.freeze
  TRADE_TARIFF_AUDIENCE = 'trade_tariff'.freeze
  HMRC_AUDIENCES = [HMRC_AUDIENCE].freeze
  FLAGGED_AUDIENCES = [HMRC_AUDIENCE, TRADE_TARIFF_AUDIENCE].freeze
  CACHE_TRUST_KEY = :frontend_authenticated
  TEAM_FIELDS = %i[
    company_name
    job_title
    enquiry_category
    other_category
    enquiry_description
    feature_flags
    search_request_id
    goods_product
    goods_made_of
    goods_used_for
    goods_function
    goods_processed
    goods_packaged
    has_commodity_code
    commodity_code
    reference_number
    created_at
  ].freeze

  Delivery = Data.define(:audience, :recipient, :form_data, :test_condition)

  def self.from(form_data, trusted_context: false)
    new(form_data: form_data.to_h.symbolize_keys.freeze, trusted_context:)
  end

  def self.from_cache(cache_payload)
    form_data = cache_payload.to_h.symbolize_keys
    trusted_context = form_data.delete(CACHE_TRUST_KEY)

    from(form_data, trusted_context: ActiveModel::Type::Boolean.new.cast(trusted_context))
  end

  def cache_payload
    form_data.merge(CACHE_TRUST_KEY => trusted_context)
  end

  def test_condition
    feature_flags.map(&:humanize).to_sentence.presence || 'none'
  end

  def feature_flagged?
    trusted_context && feature_flags.any?
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
        form_data: form_data.slice(*TEAM_FIELDS),
        test_condition:,
      )
    else
      raise ArgumentError, "Unknown enquiry email audience: #{audience}"
    end
  end

private

  def feature_flags
    Array(form_data[:feature_flags]).map(&:to_s).reject(&:blank?)
  end

  def trade_tariff_recipient
    Mail::Address.new(TradeTariffBackend.support_email).address
  end
end
