class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    SearchReference.each do |ref|
      next if ref.referenced.current?

      message = "Removed Search reference: id:#{ref.id}, title:'#{ref.title}'"

      ref.delete

      logger.info(message)

      SlackNotifierService.call(message)
    end
  end
end
