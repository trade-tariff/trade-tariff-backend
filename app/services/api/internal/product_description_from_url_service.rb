module Api
  module Internal
    class ProductDescriptionFromUrlService
      def self.call(url)
        new(url).call
      end

      def initialize(url)
        @url = url
      end

      def call
        page = ProductDescription::SafeUrlFetcher.call(@url)
        extracted_content = ProductDescription::ProductPageExtractor.call(page.body)

        unless extracted_content.sufficient?
          return ProductDescription::Result.failure(
            'Insufficient product information',
            'Could not identify enough product information from the URL',
          )
        end

        ProductDescription::ProductDescriptionGenerator.call(extracted_content, source_url: page.final_url)
      rescue ProductDescription::SafeUrlFetcher::FetchError => e
        if e.http_status?
          begin
            return generate_from_url_content
          rescue StandardError => fallback_error
            return controlled_failure(fallback_error)
          end
        end

        ProductDescription::Result.failure(e.title, e.message)
      rescue StandardError => e
        controlled_failure(e)
      end

      private

      def controlled_failure(error)
        ProductDescription::Instrumentation.description_failed(error)

        ProductDescription::Result.failure(
          'Product description failed',
          'Could not generate a product description from the URL',
        )
      end

      def generate_from_url_content
        extracted_content = ProductDescription::UrlContentExtractor.call(@url)

        unless extracted_content.sufficient?
          return ProductDescription::Result.failure(
            'Insufficient product information',
            'Could not identify enough product information from the URL',
          )
        end

        result = ProductDescription::ProductDescriptionGenerator.call(extracted_content, source_url: @url)
        return result unless result.success?

        result.with(confidence: 'low', metadata: result.metadata.merge('source' => 'url'))
      end
    end
  end
end
