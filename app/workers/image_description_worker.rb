class ImageDescriptionWorker
  include Sidekiq::Worker

  sidekiq_options queue: :image_descriptions, retry: false

  def perform(id)
    return unless ImageDescription.enabled?

    job = ImageDescription.new(id)
    payload = job.claim
    return unless payload

    begin
      image = ImageDescriptions::Normalise.call(job)
      job.complete(ImageDescriptions::Describe.call(image, request_id: payload['request_id']))
    rescue ImageDescriptions::Normalise::InvalidImage, ImageDescriptions::Describe::InvalidResponse => e
      job.fail(e.message)
    rescue StandardError => e
      job.fail('Image description is temporarily unavailable. Try again or type a description.')
      Rails.logger.warn("Image description failed: #{e.class.name}")
    ensure
      job.cleanup
    end
  end
end
