# frozen_string_literal: true

module SearchReferences
  # Builds the public frontend link for the goods nomenclature a search reference points at.
  # Uses only the values cached on the search reference, so it works for deleted references too.
  class FrontendUrl
    PATH_SEGMENTS = {
      'Chapter' => 'chapters',
      'Heading' => 'headings',
      'Subheading' => 'subheadings',
      'Commodity' => 'commodities',
    }.freeze

    def self.call(referenced_class:, goods_nomenclature_item_id:, productline_suffix:)
      return if TradeTariffBackend.frontend_host.blank?

      path_segment = PATH_SEGMENTS[referenced_class]
      return if path_segment.blank?

      code = frontend_code(referenced_class, goods_nomenclature_item_id, productline_suffix)
      return if code.blank?

      URI.join(TradeTariffBackend.frontend_host, "#{path_segment}/", code).to_s
    rescue URI::InvalidURIError
      nil
    end

    def self.frontend_code(referenced_class, item_id, productline_suffix)
      return if item_id.blank?

      case referenced_class
      when 'Chapter' then item_id.first(2)
      when 'Heading' then item_id.first(4)
      when 'Subheading' then "#{item_id}-#{productline_suffix}"
      when 'Commodity' then item_id
      end
    end
    private_class_method :frontend_code
  end
end
