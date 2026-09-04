# frozen_string_literal: true

module SearchReferences
  class InvalidationReasonService
    VALID_REASONS = {
      missing: 'Missing',
      expired: 'Expired',
      superseded: 'Superseded',
      unknown: 'Unknown',
      current: 'Current',
      future_dated: 'Future-dated',
    }.freeze

    private_constant :VALID_REASONS

    RETAINED_REASONS = %i[current future_dated].freeze

    private_constant :RETAINED_REASONS

    FRONTEND_PATH_SEGMENTS = {
      'Chapter' => 'chapters',
      'Heading' => 'headings',
      'Subheading' => 'subheadings',
      'Commodity' => 'commodities',
    }.freeze

    private_constant :FRONTEND_PATH_SEGMENTS

    def self.call(search_reference)
      new(search_reference).call
    end

    def initialize(search_reference)
      @search_reference = search_reference
    end

    def call
      {
        search_reference_id: @search_reference.id,
        title: @search_reference.title,
        referenced_class: @search_reference.referenced_class,
        productline_suffix: @search_reference.productline_suffix,
        goods_nomenclature_sid: @search_reference.goods_nomenclature_sid,
        goods_nomenclature_item_id: @search_reference.goods_nomenclature_item_id,
        reason: reason,
        reason_label: VALID_REASONS.fetch(reason),
        auto_deletion: auto_deletion?,
        removal_alert_required: removal_alert_required?,
        validity_start_date: goods_nomenclature&.validity_start_date,
        validity_end_date: goods_nomenclature&.validity_end_date,
        successor_ids: successor_ids,
        goods_nomenclature_url: goods_nomenclature_url,
      }
    end

  private

    # Missing: the stored SID no longer resolves to a goods nomenclature at all.
    # Current: the goods nomenclature is currently valid. Retained, no alert.
    # Future-dated: the validity period hasn't started yet. Retained, no alert.
    # Superseded: not current, and one or more successors can be identified.
    # Expired: not current, validity end date has passed, no successor identified.
    # Unknown: not current, but the data doesn't prove any of the above.
    def reason
      return :missing if goods_nomenclature.blank?
      return :current if goods_nomenclature.current?
      return :future_dated if future_dated?
      return :superseded if successor_ids.present?
      return :expired if expired?

      :unknown
    end

    def auto_deletion?
      %i[missing expired superseded unknown].include?(reason)
    end

    def removal_alert_required?
      RETAINED_REASONS.exclude?(reason)
    end

    def future_dated?
      goods_nomenclature.validity_start_date.present? && goods_nomenclature.validity_start_date.future?
    end

    def expired?
      goods_nomenclature.validity_end_date.present? && goods_nomenclature.validity_end_date.past?
    end

    def successor_ids
      return [] if goods_nomenclature.blank?

      @successor_ids ||= goods_nomenclature.goods_nomenclature_successors.map(&:goods_nomenclature_item_id).uniq
    end

    def goods_nomenclature
      @goods_nomenclature ||= @search_reference.referenced
    end

    # Derived from the cached referenced_class/item_id/productline_suffix on the
    # search reference itself, so it's still available even in the "missing" case.
    def goods_nomenclature_url
      return if TradeTariffBackend.frontend_host.blank?

      path_segment = FRONTEND_PATH_SEGMENTS[@search_reference.referenced_class]
      return if path_segment.blank?

      code = frontend_code
      return if code.blank?

      URI.join(TradeTariffBackend.frontend_host, "#{path_segment}/", code).to_s
    rescue URI::InvalidURIError
      nil
    end

    def frontend_code
      item_id = @search_reference.goods_nomenclature_item_id
      return if item_id.blank?

      case @search_reference.referenced_class
      when 'Chapter' then item_id.first(2)
      when 'Heading' then item_id.first(4)
      when 'Subheading' then "#{item_id}-#{@search_reference.productline_suffix}"
      when 'Commodity' then item_id
      end
    end
  end
end
