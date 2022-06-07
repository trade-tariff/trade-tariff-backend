class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    SearchReference.each do |ref|
      unless ref.referenced.current?
        logger.info "Removed Search reference: id:#{ref.id}, title:'#{ref.title}'"
        ref.delete
      end
    end
  end
end
