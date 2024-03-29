module BulkSearch
  class ResultCollection
    class RecordNotFound < StandardError; end

    delegate :processing?, :completed?, :failed?, :queued?, to: :status
    delegate :to_param, to: :id

    attr_accessor :status
    attr_reader :id, :searches

    INITIAL_STATE = :queued
    COMPLETE_STATE = :completed
    FAILED_STATE = :failed
    PROCESSING_STATE = :processing

    STATE_MESSAGES = {
      INITIAL_STATE => 'Your bulk search request has been accepted and is now on a queue waiting to be processed',
      COMPLETE_STATE => 'Completed',
      FAILED_STATE => 'Failed',
      PROCESSING_STATE => 'Processing',
    }.freeze

    HTTP_CODES = {
      INITIAL_STATE => 202, # Accepted
      PROCESSING_STATE => 202, # Accepted
      COMPLETE_STATE => 200, # OK
      FAILED_STATE => 500, # Internal Server Error
    }.freeze

    EXPIRES_IN = 2.hours

    class << self
      delegate :redis, to: TradeTariffBackend

      def enqueue(searches)
        build(searches).tap do |result|
          if result.valid?
            redis.set(
              result.id,
              Zlib::Deflate.deflate(result.to_json),
              ex: EXPIRES_IN,
            )

            BulkSearchWorker.perform_async(result.id)
          end
        end
      end

      def find(id)
        json_blob = redis.get(id)

        result = if json_blob.blank?
                   raise RecordNotFound
                 else
                   JSON.parse(Zlib::Inflate.inflate(json_blob)).deep_symbolize_keys
                 end

        new(result)
      end

      def build(searches = [])
        attributes = {
          id: SecureRandom.uuid,
          status: INITIAL_STATE,
          searches: searches.map do |search|
            search[:attributes]
          end,
        }

        new(attributes)
      end
    end

    def initialize(data = {})
      @id = data.delete(:id)
      @status = ActiveSupport::StringInquirer.new(data.delete(:status).to_s)
      @searches = (data.delete(:searches) || []).map do |search|
        attributes = search.to_h.try(:deep_symbolize_keys!) || search.to_h
        attributes[:search_results] = attributes[:search_results].presence || []
        attributes[:number_of_digits] = attributes[:number_of_digits].presence || 6

        BulkSearch::Search.build(attributes)
      end
    end

    def as_json(...)
      {
        id:,
        status:,
        searches: searches.map do |search|
          {
            input_description: search.input_description,
            search_results: search.search_results.map do |search_result|
              {
                number_of_digits: search_result.number_of_digits,
                short_code: search_result.short_code,
                score: search_result.score,
              }
            end,
          }
        end,
      }
    end

    def valid?
      searches.all?(&:valid?)
    end

    def search_ids
      searches.map(&:id)
    end

    def message
      STATE_MESSAGES[status.to_sym]
    end

    def http_code
      HTTP_CODES[status.to_sym]
    end

    def processing!
      update_status(PROCESSING_STATE)
    end

    def complete!
      update_status(COMPLETE_STATE)
    end

    def failed!
      update_status(FAILED_STATE)
    end

    private

    delegate :redis, to: TradeTariffBackend

    def update_status(status)
      self.status = ActiveSupport::StringInquirer.new(status.to_s)

      redis.set(
        id,
        Zlib::Deflate.deflate(to_json),
        ex: EXPIRES_IN,
      )
    end
  end
end
