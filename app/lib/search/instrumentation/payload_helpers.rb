module Search
  module Instrumentation
    module PayloadHelpers
      def description_intercept_payload(description_intercept, prefix: nil)
        payload = if description_intercept
                    {
                      matched: true,
                      term: description_intercept.term,
                      excluded: description_intercept.excluded,
                      filtering: description_intercept.filtering?,
                      filter_prefix_count: description_intercept.filter_prefixes_array.size,
                      guidance_level: description_intercept.guidance_level,
                      guidance_location: description_intercept.guidance_location,
                      escalate_to_webchat: description_intercept.escalate_to_webchat,
                    }
                  else
                    { matched: false }
                  end

        return payload unless prefix

        payload.transform_keys { |key| [prefix, key].join('_').to_sym }
      end

      def truncate_error_payload(error_message)
        return {} if error_message.blank?

        message = error_message.to_s

        {
          error_message: message.first(ERROR_MESSAGE_MAX_LENGTH),
          error_message_truncated: message.length > ERROR_MESSAGE_MAX_LENGTH,
        }
      end

      def truncate_reason_payload(reason)
        return { reason: nil, reason_truncated: false } if reason.blank?

        message = reason.to_s
        {
          reason: message.first(ERROR_MESSAGE_MAX_LENGTH),
          reason_truncated: message.length > ERROR_MESSAGE_MAX_LENGTH,
        }
      end

      def with_request_context(payload)
        return payload unless payload.key?(:request_id)

        payload
          .merge(request_id: payload[:request_id].presence || TradeTariffRequest.request_id.presence || SecureRandom.uuid)
          .merge(request_source_payload)
      end

      def request_source_payload
        return {} if TradeTariffRequest.request_source.blank?

        { request_source: TradeTariffRequest.request_source }
      end
    end
  end
end
