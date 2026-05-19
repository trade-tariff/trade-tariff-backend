module Api
  module Internal
    module ProductDescription
      class ExtractedContent < Data.define(
        :title,
        :meta_description,
        :open_graph_title,
        :open_graph_description,
        :h1,
        :product_data,
        :body_text,
      )
        def sufficient?
          product_data.present? ||
            [
              title,
              meta_description,
              open_graph_title,
              open_graph_description,
              h1,
            ].any?(&:present?)
        end

        def to_prompt_payload
          {
            title:,
            meta_description:,
            open_graph_title:,
            open_graph_description:,
            h1:,
            product_data:,
            body_text:,
          }.compact_blank
        end
      end
    end
  end
end
