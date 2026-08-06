class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    cleared = SearchReference.each_with_object({}) do |search_reference, acc|
      next if search_reference.referenced.current?

      (acc[search_reference.goods_nomenclature_sid] ||= []) << search_reference.title

      search_reference.delete
    end

    logger.info("Removed Search references #{cleared.to_json}") if cleared.any?
  end
end
