class BulkSearch
  INITIAL_STATE = :queued
  COMPLETE_STATE = :completed
  FAILED_STATE = :failed
  NOT_FOUND_STATE = :not_found
  PROCESSING_STATE = :processing

  STATE_MESSAGES = {
    INITIAL_STATE => 'Queued',
    COMPLETE_STATE => 'Completed',
    FAILED_STATE => 'Failed',
    NOT_FOUND_STATE => 'Not found',
    PROCESSING_STATE => 'Processing',
  }.freeze

  HTTP_CODES = {
    INITIAL_STATE => 202, # Accepted
    PROCESSING_STATE => 202, # Accepted
    COMPLETE_STATE => 200, # OK
    FAILED_STATE => 500, # Internal Server Error
    NOT_FOUND_STATE => 404, # Not Found
  }.freeze
  TWO_HOURS = 60 * 60 * 2

  class << self
    delegate :redis, to: TradeTariffBackend

    def enqueue(searches)
      ResultCollection.build(searches).tap do |result|
        redis.set(
          result.id,
          Zlib::Deflate.deflate(result.to_json),
          ex: TWO_HOURS,
        )

        BulkSearchWorker.perform_async(result.id)
      end
    end

    def find(id)
      decompressed = Zlib::Inflate.inflate(redis.get(id))

      result = if decompressed.blank?
                 {
                   id:,
                   status: NOT_FOUND_STATE,
                 }
               else
                 JSON.parse(decompressed).deep_symbolize_keys
               end

      ResultCollection.new(result)
    end
  end
end
