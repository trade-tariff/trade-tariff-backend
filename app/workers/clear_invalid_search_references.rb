class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    cleared = SearchReference.each_with_object({}) do |search_reference, acc|
      next if search_reference.referenced.current?

      (acc[search_reference.goods_nomenclature_sid] ||= []) << search_reference.title

      search_reference.delete
    end

    if cleared.any?
      message = "Removed Search references #{cleared.to_json}"

      logger.info(message)
      SlackNotifierService.call(message)
    end
  end
end
