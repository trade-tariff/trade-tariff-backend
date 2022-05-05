class Healthcheck
  REVISION_FILE = Rails.root.join('REVISION').to_s.freeze
  SIDEKIQ_KEY = 'sidekiq-healthcheck'.freeze
  SIDEKIQ_THRESHOLD = 90.minutes

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
    check_postgres!

    {
      git_sha1: current_revision,
      sidekiq: sidekiq_healthy?,
    }
  end

private

  def check_postgres!
    Section.all
  end

  def sidekiq_healthy?
    if (healthcheck_time = Rails.cache.read(SIDEKIQ_KEY))
      Time.zone.parse(healthcheck_time) >= SIDEKIQ_THRESHOLD.ago
    else
      false
    end
  end
end
