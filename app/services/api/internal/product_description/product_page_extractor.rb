module Api
  module Internal
    module ProductDescription
      class ProductPageExtractor
        BODY_TEXT_LIMIT = 2_000

        def self.call(html)
          new(html).call
        end

        def initialize(html)
          @html = html.to_s
        end

        def call
          doc = Nokogiri::HTML5.parse(@html)
          doc.css('script:not([type="application/ld+json"]), style, noscript').remove

          ExtractedContent.new(
            title: text_at(doc, 'title'),
            meta_description: meta_content(doc, 'meta[name="description"]'),
            open_graph_title: meta_content(doc, 'meta[property="og:title"]'),
            open_graph_description: meta_content(doc, 'meta[property="og:description"]'),
            h1: text_at(doc, 'h1'),
            product_data: product_data(doc),
            body_text: body_text(doc),
          )
        end

        private

        def text_at(doc, selector)
          normalize_text(doc.at_css(selector)&.text)
        end

        def meta_content(doc, selector)
          normalize_text(doc.at_css(selector)&.attr('content'))
        end

        def body_text(doc)
          normalize_text(doc.at_css('body')&.text || doc.text).to_s.first(BODY_TEXT_LIMIT)
        end

        def product_data(doc)
          doc.css('script[type="application/ld+json"]').each_with_object({}) do |script, data|
            product_nodes(JSON.parse(script.text)).each do |node|
              data.merge!(extract_product_fields(node))
            end
          rescue JSON::ParserError
            next
          end
        end

        def product_nodes(value)
          case value
          when Array
            value.flat_map { |item| product_nodes(item) }
          when Hash
            graph_nodes = product_nodes(value['@graph'])
            current_node = product_type?(value['@type']) ? [value] : []
            current_node + graph_nodes
          else
            []
          end
        end

        def product_type?(type)
          Array(type).map(&:to_s).include?('Product')
        end

        def extract_product_fields(node)
          {
            'name' => normalize_text(node['name']),
            'brand' => normalize_brand(node['brand']),
            'material' => normalize_text(Array(node['material']).join(', ')),
            'description' => normalize_text(node['description']),
          }.compact_blank
        end

        def normalize_brand(brand)
          case brand
          when Hash
            normalize_text(brand['name'])
          when Array
            normalize_text(brand.map { |entry| entry.is_a?(Hash) ? entry['name'] : entry }.compact.join(', '))
          else
            normalize_text(brand)
          end
        end

        def normalize_text(value)
          value.to_s.gsub(/\s+/, ' ').strip.presence
        end
      end
    end
  end
end
