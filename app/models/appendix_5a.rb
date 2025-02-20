class Appendix5a < Sequel::Model(:appendix_5as)
  CDS_GUIDANCE_OBJECT_KEY = 'config/cds_guidance.json'.freeze

  set_primary_key %i[certificate_type_code certificate_code]

  plugin :timestamps, update_on_create: true
  plugin :dirty

  def self.fetch_latest
    if Rails.application.config.persistence_bucket.present?
      guidance = Rails.application.config.persistence_bucket.object(CDS_GUIDANCE_OBJECT_KEY).get.body.read
      JSON.parse(guidance)
    end
  rescue JSON::ParserError, Aws::S3::Errors::ServiceError
    nil
  end

  def document_code
    "#{certificate_type_code}#{certificate_code}"
  end

  def guidance_chief
    chief_guidance || ''
  end

  def guidance_cds
    cds_guidance
  end
end
