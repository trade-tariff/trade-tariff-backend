module Api
  module Internal
    module ProductDescription
      class Result < Data.define(:success, :description, :source_url, :confidence, :metadata, :error_title, :error_detail)
        def success?
          success
        end

        class << self
          def success(description:, source_url:, confidence:, metadata:)
            new(true, description, source_url, confidence, metadata, nil, nil)
          end

          def failure(title, detail)
            new(false, nil, nil, nil, {}, title, detail)
          end
        end
      end
    end
  end
end
