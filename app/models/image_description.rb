class ImageDescription
  RETENTION = 10.minutes
  MAX_BYTES = 15.megabytes
  MAX_PENDING = 3
  ID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  MIME_TYPES = %w[image/jpeg image/png image/webp image/gif image/heic image/heif image/avif image/tiff].freeze
  InvalidUpload = Class.new(StandardError)
  TooLarge = Class.new(InvalidUpload)
  UnsupportedFormat = Class.new(InvalidUpload)
  Busy = Class.new(StandardError)

  TRANSITION = <<~LUA.freeze
    if redis.call('GET', KEYS[1]) == ARGV[1] then
      redis.call('SET', KEYS[1], ARGV[2], 'KEEPTTL')
      return 1
    end
    return 0
  LUA

  attr_reader :id

  def self.root
    Rails.root.join('tmp/image_descriptions', TradeTariffBackend.service)
  end

  def self.create(upload, request_id:)
    raise InvalidUpload, 'Choose an image file.' unless upload.is_a?(ActionDispatch::Http::UploadedFile)
    raise TooLarge, 'Choose an image smaller than 15 MB.' if upload.size > MAX_BYTES
    raise InvalidUpload, 'Choose an image that is not empty.' unless upload.size.positive?
    raise UnsupportedFormat, 'Choose a JPEG, PNG, WebP, GIF, HEIC, HEIF, AVIF or TIFF image.' unless MIME_TYPES.include?(Marcel::MimeType.for(upload.tempfile))

    FileUtils.mkdir_p(root, mode: 0o700)
    File.open(root.join('.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      directories = root.children.select { |path| path.basename.to_s.match?(ID_PATTERN) && path.directory? }
      directories.each { |path| FileUtils.remove_entry(path) if path.mtime < RETENTION.ago }
      raise Busy if directories.count(&:exist?) >= MAX_PENDING

      job = new(SecureRandom.uuid)
      begin
        Dir.mkdir(job.directory, 0o700)
        File.open(job.input_path, 'wb', 0o600) { |file| IO.copy_stream(upload.tempfile, file) }
        now = Time.current.iso8601
        payload = { id: job.id, status: 'queued', request_id:, created_at: now }
        Sidekiq.redis { |redis| redis.set(job.key, payload.to_json, ex: RETENTION.to_i) }
        job
      rescue StandardError
        job.cleanup
        raise
      end
    end
  end

  def initialize(id)
    raise ArgumentError, 'Invalid image description ID' unless id.is_a?(String) && id.match?(ID_PATTERN)

    @id = id
  end

  def key = "image_description:#{TradeTariffBackend.service}:#{id}"
  def directory = self.class.root.join(id)
  def input_path = directory.join('input')

  def payload
    stored = Sidekiq.redis { |redis| redis.get(key) }
    JSON.parse(stored) if stored
  end

  def claim = transition(from: 'queued', status: 'running')

  def complete(result)
    transition(from: 'running', status: 'completed', **result.symbolize_keys)
  end

  def fail(message)
    transition(from: 'running', status: 'failed', error: message)
  end

  def delete
    Sidekiq.redis { |redis| redis.del(key) }
  ensure
    cleanup
  end

  def cleanup
    FileUtils.remove_entry(directory) if directory.directory?
  end

private

  def transition(from:, **attributes)
    Sidekiq.redis do |redis|
      previous = redis.get(key)
      next unless previous

      payload = JSON.parse(previous)
      next unless payload['status'] == from

      updated = payload.merge(attributes.stringify_keys)
      updated if redis.call('EVAL', TRANSITION, 1, key, previous, updated.to_json) == 1
    end
  end
end
