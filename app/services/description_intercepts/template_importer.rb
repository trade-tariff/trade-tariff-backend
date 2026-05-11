# frozen_string_literal: true

require 'csv'

module DescriptionIntercepts
  class TemplateImporter
    Result = Data.define(:created_count, :updated_count, :summary_errors, :row_errors) do
      def success?
        summary_errors.empty? && row_errors.empty?
      end

      def total_count
        created_count + updated_count
      end
    end

    REQUIRED_HEADERS = %w[term template].freeze
    OPTIONAL_HEADERS = %w[aliases].freeze
    ALLOWED_HEADERS = (REQUIRED_HEADERS + OPTIONAL_HEADERS).freeze
    TEMPLATE_ATTRIBUTES = %w[
      sources
      message_header
      message
      excluded
      guidance_level
      guidance_location
      escalate_to_webchat
      filter_prefixes
    ].freeze

    def initialize(csv_content:)
      @csv_content = csv_content.to_s
      @summary_errors = []
      @row_errors = []
    end

    def call
      rows = parse_rows
      return failure_result if errors?

      candidates = build_candidates(rows)
      return failure_result if errors?

      persist(candidates)
    rescue CSV::MalformedCSVError => e
      @summary_errors << error(detail: "CSV could not be parsed: #{e.message}")
      failure_result
    end

    private

    def parse_rows
      csv = CSV.parse(@csv_content, headers: true, skip_blanks: true)
      validate_headers(csv.headers)
      return [] if errors?

      csv.each_with_index.filter_map do |row, index|
        next if row.to_h.values.all?(&:blank?)

        {
          line_number: index + 2,
          term: DescriptionIntercept.normalize_alias(row['term']),
          aliases: parse_aliases(row['aliases']),
          template: row['template'].to_s.squish,
        }
      end
    end

    def validate_headers(headers)
      normalized_headers = Array(headers).compact.map(&:strip)
      @aliases_header_present = normalized_headers.include?('aliases')

      unless (REQUIRED_HEADERS - normalized_headers).empty? && (normalized_headers - ALLOWED_HEADERS).empty?
        @summary_errors << error(detail: 'CSV must contain term and template columns, and may include an aliases column')
      end
    end

    def build_candidates(rows)
      validate_duplicate_search_values(rows)
      validate_required_cells(rows)
      validate_templates(rows)
      return [] if errors?

      rows.map do |row|
        existing = DescriptionIntercept.first(term: row[:term])
        attrs = template_attributes(row[:template]).merge(term: row[:term])
        if @aliases_header_present
          attrs[:aliases] = row[:aliases]
        elsif existing
          attrs[:aliases] = existing.aliases
        end
        intercept = existing || DescriptionIntercept.new
        coerced_attrs = coerce_attributes(attrs)
        intercept.set(coerced_attrs)

        unless intercept.valid?
          intercept.errors.each do |attribute, messages|
            messages.each do |message|
              @row_errors << error(
                detail: "#{row[:term]} #{attribute} #{message}",
                pointer: "/data/attributes/csv/#{row[:line_number]}/#{attribute}",
              )
            end
          end
        end

        { existing:, attrs: coerced_attrs }
      end
    end

    def validate_duplicate_search_values(rows)
      duplicate_values = rows.flat_map { |row| [row[:term], *row[:aliases]] }.compact_blank.tally.select { |_value, count| count > 1 }.keys
      duplicate_values.each do |value|
        @summary_errors << error(
          detail: "#{value} appears more than once across terms and aliases",
          meta: { code: 'duplicate_search_value', value: value },
        )
      end
    end

    def parse_aliases(value)
      value.to_s.split(',').map { |aliaz| DescriptionIntercept.normalize_alias(aliaz) }.compact_blank.uniq
    end

    def validate_required_cells(rows)
      rows.each do |row|
        @row_errors << error(detail: 'term is required', pointer: "/data/attributes/csv/#{row[:line_number]}/term") if row[:term].blank?
        @row_errors << error(detail: 'template is required', pointer: "/data/attributes/csv/#{row[:line_number]}/template") if row[:template].blank?
      end
    end

    def validate_templates(rows)
      invalid_templates = rows.map { |row| row[:template] }.compact_blank.reject { |template| templates.key?(template) }.uniq
      return if invalid_templates.empty?

      @summary_errors << error(
        detail: invalid_template_summary(invalid_templates),
        meta: { code: 'invalid_templates', values: invalid_templates },
      )
    end

    def invalid_template_summary(invalid_templates)
      return "#{invalid_templates.first} is not a valid template" if invalid_templates.one?

      "#{to_sentence(invalid_templates)} are not valid templates"
    end

    def persist(candidates)
      created = 0
      updated = 0

      Sequel::Model.db.transaction do
        candidates.each do |candidate|
          intercept = candidate[:existing] || DescriptionIntercept.new
          intercept.set(candidate[:attrs])
          unless intercept.save(raise_on_failure: false)
            intercept.errors.each do |attribute, messages|
              messages.each { |message| @summary_errors << error(detail: "#{attribute} #{message}") }
            end
            raise Sequel::Rollback
          end

          candidate[:existing] ? updated += 1 : created += 1
        end
      end

      return failure_result if errors?

      Result.new(created_count: created, updated_count: updated, summary_errors: [], row_errors: [])
    end

    def template_attributes(template)
      templates.fetch(template).fetch('attributes').slice(*TEMPLATE_ATTRIBUTES).symbolize_keys
    end

    def templates
      @templates ||= AdminConfiguration.description_intercept_templates_value
    end

    def coerce_attributes(attrs)
      attrs.merge(
        sources: Sequel.pg_array(Array(attrs[:sources]).compact_blank, :text),
        filter_prefixes: Sequel.pg_array(Array(attrs[:filter_prefixes]).compact_blank, :text),
        aliases: Sequel.pg_array(Array(attrs[:aliases]).compact_blank, :text),
      )
    end

    def failure_result
      Result.new(created_count: 0, updated_count: 0, summary_errors: @summary_errors, row_errors: @row_errors)
    end

    def errors?
      @summary_errors.any? || @row_errors.any?
    end

    def error(detail:, pointer: nil, meta: nil)
      {}.tap do |payload|
        payload[:detail] = detail
        payload[:source] = { pointer: } if pointer
        payload[:meta] = meta if meta
      end
    end

    def to_sentence(values)
      case values.length
      when 0 then ''
      when 1 then values.first
      when 2 then values.join(' and ')
      else "#{values[0...-1].join(', ')} and #{values.last}"
      end
    end
  end
end
