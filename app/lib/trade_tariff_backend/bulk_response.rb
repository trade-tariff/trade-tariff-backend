module TradeTariffBackend
  # OpenSearch answers a `_bulk` request with HTTP 200 even when individual
  # items in that request failed. The per item outcome only shows up in the
  # response body, as an `"errors" => true` flag plus an `"error"` object on
  # each failed item. A caller that ignores the body therefore treats a
  # partially (or entirely) rejected bulk as a success.
  #
  # `check!` inspects that body and raises with enough detail to diagnose the
  # failure, while keeping the message small enough for a log line or a Slack
  # alert. A bulk of 500 rejected items must not produce 500 error objects of
  # output, so we report the first few failures and a count by error type.
  module BulkResponse
    BulkError = Class.new(StandardError)

    # A failure that will fail identically on every retry, such as a mapping
    # error or a malformed document.
    BulkIndexingError = Class.new(BulkError)

    # Transient backpressure: the cluster's write queue was full and shed the
    # work. The same documents would very likely succeed later.
    BulkRejectedError = Class.new(BulkError)

    REJECTED_ERROR_TYPE = 'es_rejected_execution_exception'.freeze
    UNKNOWN_ERROR_TYPE = 'unknown'.freeze

    # Bounds on the error message. Five failures is enough to spot a pattern,
    # and the type counts cover the rest.
    MAX_REPORTED_FAILURES = 5
    MAX_REASON_LENGTH = 200

    # Returns the response unchanged when every item succeeded, otherwise
    # raises BulkRejectedError (all failures were queue rejections) or
    # BulkIndexingError (anything else).
    def self.check!(response, context)
      return response unless response.is_a?(Hash)
      return response unless response['errors']

      failures = failures_in(response)

      # The flag is authoritative: if OpenSearch says something failed we raise
      # even when we cannot attribute it to an item.
      raise BulkIndexingError, "#{context}: bulk response reported errors but no item carried an error object (unknown failure)" if failures.empty?

      error_class = failures.all? { |failure| failure[:type] == REJECTED_ERROR_TYPE } ? BulkRejectedError : BulkIndexingError

      raise error_class, message_for(context, failures, response)
    end

    # Each item is keyed by its operation, e.g.
    # { "index" => { "_id" => "1", "status" => 429, "error" => { "type" => ..., "reason" => ... } } }
    def self.failures_in(response)
      items = response['items']
      return [] unless items.is_a?(Array)

      failures = []

      items.each do |item|
        next unless item.is_a?(Hash)

        operation, result = item.first
        next unless result.is_a?(Hash)

        status = result['status'].to_i
        error = result['error']
        next if error.nil? && status < 400

        error = {} unless error.is_a?(Hash)

        failures.push(
          operation:,
          id: result['_id'],
          status: result['status'],
          type: error['type'].presence || UNKNOWN_ERROR_TYPE,
          reason: error['reason'].to_s,
        )
      end

      failures
    end

    def self.message_for(context, failures, response)
      total_items = response['items'].is_a?(Array) ? response['items'].size : failures.size
      reported = failures.take(MAX_REPORTED_FAILURES).map { |failure| describe_failure(failure) }
      remainder = failures.size - reported.size
      reported.push("and #{remainder} more") if remainder.positive?

      "#{context}: #{failures.size} of #{total_items} bulk items failed. " \
        "Counts by error type: #{counts_by_type(failures)}. " \
        "First failures: #{reported.join('; ')}"
    end

    def self.describe_failure(failure)
      reason = failure[:reason]
      reason = "#{reason[0, MAX_REASON_LENGTH]}..." if reason.length > MAX_REASON_LENGTH

      "#{failure[:operation]} id=#{failure[:id]} status=#{failure[:status]} #{failure[:type]}: #{reason}"
    end

    def self.counts_by_type(failures)
      failures.group_by { |failure| failure[:type] }
              .map { |type, grouped| "#{type}: #{grouped.size}" }
              .join(', ')
    end

    private_class_method :failures_in, :message_for, :describe_failure, :counts_by_type
  end
end
