class Healthcheck
  include Singleton

  REVISION_FILE = Rails.root.join('REVISION').to_s.freeze
  SIDEKIQ_KEY = 'sidekiq-healthcheck'.freeze
  SIDEKIQ_THRESHOLD = 90.minutes

  class << self
    delegate :check, to: :instance
  end

  def check
    check_postgres!

    {
      git_sha1: current_revision,
      sidekiq: sidekiq_healthy?,
    }
  end

  def current_revision
    @current_revision ||= read_revision_file || Rails.env.to_s
  end

private

  def read_revision_file
    File.read(REVISION_FILE).chomp if File.file?(REVISION_FILE)
  rescue Errno::EACCES
    nil
  end

  def check_postgres!
    Section.all
  end

  def sidekiq_healthy?
    if (healthcheck_time = read_last_sidekiq_healthcheck)
      Time.zone.parse(healthcheck_time) >= SIDEKIQ_THRESHOLD.ago
    else
      false
    end
  end

  def read_last_sidekiq_healthcheck
    Sidekiq.redis do |redis|
      redis.get(SIDEKIQ_KEY)
    end
  end
end
