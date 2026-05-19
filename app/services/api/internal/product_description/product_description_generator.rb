module Api
  module Internal
    module ProductDescription
      class ProductDescriptionGenerator
        VALID_CONFIDENCE = %w[low medium high].freeze

        def self.call(extracted_content, source_url:)
          new(extracted_content, source_url:).call
        end

        def initialize(extracted_content, source_url:)
          @extracted_content = extracted_content
          @source_url = source_url
        end

        def call
          response = AiResponseSanitizer.call(
            OpenaiClient.call(messages, model: configured_model, reasoning_effort: configured_reasoning_effort),
          )
          return malformed_response('Generated response was not valid') unless response.is_a?(Hash)

          description = response['description'].to_s.strip
          return malformed_response('Generated description was blank') if description.blank?

          Result.success(
            description:,
            source_url: @source_url,
            confidence: normalize_confidence(response['confidence']),
            metadata: normalize_metadata(response['metadata']),
          )
        end

        private

        def messages
          [
            {
              role: 'system',
              content: system_prompt,
            },
            {
              role: 'user',
              content: JSON.generate(@extracted_content.to_prompt_payload),
            },
          ]
        end

        def system_prompt
          <<~PROMPT.squish
            Convert extracted product page information into JSON for commodity search.
            Return only JSON with description, confidence, and metadata.
            The description must state what the product is, what it is made from,
            and essential attributes such as use, form, dimensions, or packaging
            only when the extracted content supports them. Do not infer unsupported claims.
            Confidence must be one of low, medium, or high.
          PROMPT
        end

        def normalize_confidence(value)
          confidence = value.to_s.downcase
          VALID_CONFIDENCE.include?(confidence) ? confidence : 'medium'
        end

        def normalize_metadata(value)
          return {} unless value.is_a?(Hash)

          value.each_with_object({}) do |(key, metadata_value), result|
            next if metadata_value.blank?

            result[key.to_s] = metadata_value.to_s.strip
          end
        end

        def malformed_response(detail)
          Result.failure('Malformed product description', detail)
        end

        def model_config
          @model_config ||= AdminConfiguration.nested_options_value('product_description_model')
        end

        def configured_model
          model_config[:selected]
        end

        def configured_reasoning_effort
          model_config[:sub_values]['reasoning_effort']
        end
      end
    end
  end
end
