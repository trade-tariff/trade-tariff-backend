class ChiefCdsGuidance
  DEFAULT_SOURCE_PATH = Rails.root.join('db/').freeze
  DEFAULT_FILE = 'chief_cds_guidance_20220404.json'.freeze

  def self.load_default
    new(DEFAULT_SOURCE_PATH.join(DEFAULT_FILE)).tap(&:guidance)
  end

  def initialize(source_file)
    @source_file = source_file
  end

  def guidance
    @guidance ||= JSON.parse(File.read(@source_file))
  end

  def guidance_for(document_code)
    guidance[document_code]
  end
end
