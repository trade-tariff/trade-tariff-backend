# frozen_string_literal: true

module SearchReferences
  # Formats one search reference change as a single line, for example:
  #   0101210000 — live horses [FPO only] (https://.../commodities/0101210000) (successors: 0101999000)
  # The invalidation alert and the monthly changes report both use this format.
  class ChangeLineFormatter
    def self.format_line(change)
      new(change).format_line
    end

    def self.format_list(changes)
      changes.map { |change| "* #{format_line(change)}" }.join("\n")
    end

    def initialize(change)
      @change = change
    end

    def format_line
      line = "#{change[:goods_nomenclature_item_id]} — #{change[:title]}"
      line += ' [FPO only]' if change[:usage] == SearchReference::FPO_USAGE
      line += " (#{change[:goods_nomenclature_url]})" if change[:goods_nomenclature_url].present?
      line += " (successors: #{change[:successor_ids].join(', ')})" if change[:successor_ids].present?
      line += " (previously: #{previous_values.join(', ')})" if previous_values.any?
      line
    end

  private

    attr_reader :change

    def previous_values
      @previous_values ||= [].tap do |values|
        values << "commodity #{change[:previous_goods_nomenclature_item_id]}" if changed?(:goods_nomenclature_item_id)
        values << "title \"#{change[:previous_title]}\"" if changed?(:title)
        values << "usage #{change[:previous_usage]}" if changed?(:usage)
      end
    end

    def changed?(field)
      previous = change[:"previous_#{field}"]
      previous.present? && previous != change[field]
    end
  end
end
