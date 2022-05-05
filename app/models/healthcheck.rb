class Healthcheck
  REVISION_FILE = Rails.root.join('REVISION').to_s.freeze

  delegate :current_revision, to: self

  class << self
    def current_revision
      @current_revision ||= read_revision_file || Rails.env.to_s
    end

  private

    def read_revision_file
      File.read(REVISION_FILE).chomp if File.file?(REVISION_FILE)
    rescue Errno::EACCES
      nil
    end
  end

  def check
    Section.all

    {
      git_sha1: current_revision,
    }
  end
end
