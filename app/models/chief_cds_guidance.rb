class ChiefCdsGuidance
  FALLBACK_SOURCE_PATH = Rails.root.join('db/chief_cds_guidance.json').freeze
  DEFAULT_EMPTY_GUIDANCE = 'No additional information is available.'.freeze
  CHIEF_GUIDANCE_KEY = 'guidance_chief'.freeze
  CDS_GUIDANCE_KEY = 'guidance_cds'.freeze
  CDS_GUIDANCE_OBJECT_KEY = 'config/chief_cds_guidance.json'.freeze

  class << self
    def load_latest
      if Rails.application.config.chief_cds_guidance_bucket.present?
        guidance = Rails.application.config.chief_cds_guidance_bucket.object(CDS_GUIDANCE_OBJECT_KEY).get.body.read
        guidance = JSON.parse(guidance)

        new(guidance) if guidance.present?
      end
    rescue Aws::S3::Errors::NoSuchKey, JSON::ParserError, Aws::S3::Errors::ServiceError
      nil
    end

    def load_fallback
      guidance = FALLBACK_SOURCE_PATH.read
      guidance = JSON.parse(guidance)

      new(guidance) if guidance.present?
    end
  end

  attr_accessor :guidance_last_updated_at
  attr_reader :guidance

  def initialize(guidance)
    @guidance = guidance
  end

  def cds_guidance_for(document_code)
    return nil if document_code.blank?

    guidance_for(document_code).try(:[], CDS_GUIDANCE_KEY).presence || DEFAULT_EMPTY_GUIDANCE
  end

  def chief_guidance_for(document_code)
    return nil if document_code.blank?

    guidance_for(document_code).try(:[], CHIEF_GUIDANCE_KEY).presence || DEFAULT_EMPTY_GUIDANCE
  end

  private


  def guidance_for(document_code)
    guidance.fetch(document_code, DEFAULT_EMPTY_GUIDANCE)
  end
end
