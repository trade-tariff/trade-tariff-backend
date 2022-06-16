# frozen_string_literal: true

class ChiefCdsGuidance
  DEFAULT_SOURCE_PATH = Rails.root.join('db/')
  DEFAULT_FILE = 'chief_cds_guidance.json'
  DEFAULT_EMPTY_GUIDANCE = 'No additional information is available.'
  CHIEF_GUIDANCE_KEY = 'guidance_chief'
  CDS_GUIDANCE_KEY = 'guidance_cds'

  def self.load_default
    new(DEFAULT_SOURCE_PATH.join(DEFAULT_FILE)).tap(&:guidance)
  end

  def initialize(source_file)
    @source_file = source_file
  end

  def guidance
    @guidance ||= JSON.parse(File.read(@source_file))
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
