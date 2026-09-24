# frozen_string_literal: true

module SearchExport
  class TerminalPage < Data.define(:end_page_type, :results)
    ResultLine = Data.define(:commodity_code, :description, :confidence_label)
    RESULT = 'Result'
    INTERCEPT = 'Intercept'
    NO_RESULT = 'No result'

    def self.from_response(response)
      Classifier.new(response).classify
    end

    class Classifier
      KNOWN_CONFIDENCE = %w[strong good possible unlikely].freeze
      LABEL_FOR = { 'strong' => 'Strong', 'good' => 'Good', 'possible' => 'Possible' }.freeze
      LABEL_ORDER = { 'Strong' => 0, 'Good' => 1, 'Possible' => 2 }.freeze
      FRONTEND_DEFAULT_LIMIT = 5

      def initialize(response)
        @response = response || {}
        @raw_confidence = {}
      end

      def classify
        return exact_match_page if exact_match?
        return nil if pending_question?
        return page(INTERCEPT, []) if blocking_guidance?

        lines = shown_lines
        return page(NO_RESULT, []) if lines.empty? || all_unknown?(lines)

        page(RESULT, ordered(lines))
      end

    private

      attr_reader :response

      def page(end_page_type, results)
        TerminalPage.new(end_page_type:, results:)
      end

      def exact_match_page
        line = result_line(items.first)
        page(RESULT, line ? [line] : [])
      end

      def exact_match?
        items.size == 1 && attribute(items.first, :score).nil?
      end

      def pending_question?
        last = answers.last
        return false unless last

        value(last, :answer).blank?
      end

      def blocking_guidance?
        ActiveModel::Type::Boolean.new.cast(value(intercept, :excluded)) &&
          value(intercept, :message_header).present? &&
          value(intercept, :message).present?
      end

      def shown_lines
        lines = items.filter_map { |item| result_line(item) }
        limit = display_limit
        return lines if limit.nil? || limit.zero?

        lines.first(limit)
      end

      def display_limit
        return nil if interactive.blank?

        raw = value(interactive, :result_limit)
        return FRONTEND_DEFAULT_LIMIT if raw.nil?

        raw.to_i
      end

      def ordered(lines)
        lines.sort_by.with_index { |line, index| [LABEL_ORDER.fetch(line.confidence_label, 3), index] }
      end

      def all_unknown?(lines)
        lines.none? { |line| KNOWN_CONFIDENCE.include?(@raw_confidence[line]) }
      end

      def result_line(item)
        code = attribute(item, :goods_nomenclature_item_id).to_s
        description = plain_heading(attribute(item, :classification_description))
        confidence = attribute(item, :confidence).to_s.downcase
        line = ResultLine.new(commodity_code: code, description:, confidence_label: LABEL_FOR[confidence].to_s)
        @raw_confidence[line] = confidence
        line
      end

      def plain_heading(text)
        sanitized = ActionController::Base.helpers.sanitize(text.to_s, tags: %w[br sub sup], attributes: [])
        fragment = Nokogiri::HTML.fragment(sanitized)
        fragment.css('br').each { |node| node.replace(Nokogiri::XML::Text.new(' ', fragment.document)) }
        fragment.text.gsub(/[[:space:]]+/, ' ').strip
      end

      def items
        @items ||= Array(response[:data] || response['data'])
      end

      def meta
        @meta ||= response[:meta] || response['meta'] || {}
      end

      def intercept
        @intercept ||= value(meta, :description_intercept) || {}
      end

      def interactive
        @interactive ||= value(meta, :interactive_search) || {}
      end

      def answers
        Array(value(interactive, :answers))
      end

      def attribute(item, key)
        attributes = item[:attributes] || item['attributes'] || item
        value(attributes, key)
      end

      def value(hash, key)
        return if hash.blank?

        hash[key].nil? ? hash[key.to_s] : hash[key]
      end
    end
  end
end
