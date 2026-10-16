# frozen_string_literal: true

module SearchReferences
  # One search reference change, built from a paper trail version. The section follows the
  # invalidation alert for automatic removals, then Added, Updated and Manually deleted.
  ChangeEntry = Data.define(
    :version_id,
    :search_reference_id,
    :section,
    :changed_at,
    :changed_by,
    :changed_by_name,
    :goods_nomenclature_item_id,
    :productline_suffix,
    :title,
    :usage,
    :goods_nomenclature_url,
    :successor_ids,
    :previous_goods_nomenclature_item_id,
    :previous_title,
    :previous_usage,
  ) do
    self::SECTIONS = {
      missing: 'Missing',
      expired: 'Expired',
      superseded: 'Superseded',
      unknown: 'Unknown',
      added: 'Added',
      updated: 'Updated',
      deleted: 'Manually deleted',
    }.freeze

    self::REMOVAL_SECTIONS = InvalidationReasonService::REMOVAL_REASONS
    self::UNKNOWN_SOURCE = 'Unknown'

    # Versions written before admin sent user names have no name.
    def initialize(changed_by_name: nil, **)
      super
    end

    class << self
      # Expects version.previous_version to be preloaded (see Version.preload_predecessors).
      def from_version(version)
        object = version.object
        previous = version.event == 'update' ? version.previous_version&.object : nil
        removal = automatic_removal?(version) ? removal_details(version) : {}

        new(
          version_id: version.id,
          search_reference_id: version.item_id,
          section: removal.fetch(:section) { section_for(version.event) },
          changed_at: version.created_at,
          changed_by: version.whodunnit.presence || self::UNKNOWN_SOURCE,
          changed_by_name: version.whodunnit_name.presence,
          goods_nomenclature_item_id: object['goods_nomenclature_item_id'],
          productline_suffix: object['productline_suffix'],
          title: object['title'],
          usage: object['usage'].presence || SearchReference::SEARCH_USAGE,
          goods_nomenclature_url: FrontendUrl.call(
            referenced_class: object['referenced_class'],
            goods_nomenclature_item_id: object['goods_nomenclature_item_id'],
            productline_suffix: object['productline_suffix'],
          ),
          successor_ids: removal.fetch(:successor_ids, []),
          previous_goods_nomenclature_item_id: previous&.dig('goods_nomenclature_item_id'),
          previous_title: previous&.dig('title'),
          previous_usage: previous && (previous['usage'].presence || SearchReference::SEARCH_USAGE),
        )
      end

    private

      def section_for(event)
        case event
        when 'create' then :added
        when 'update' then :updated
        else :deleted
        end
      end

      def automatic_removal?(version)
        version.event == 'destroy' && ChangeSource.automatic_removal?(version.whodunnit)
      end

      # Uses the reason that ClearInvalidSearchReferences stored on the destroy version at
      # removal time. It does not run InvalidationReasonService again, because the tariff data
      # can change after the removal. Versions without a stored reason (removals before the
      # reason was stored, and backfilled versions) are shown as unknown.
      def removal_details(version)
        metadata = version.metadata.to_h
        reason = metadata['removal_reason'].to_s.presence&.to_sym
        section = self::REMOVAL_SECTIONS.include?(reason) ? reason : :unknown

        { section:, successor_ids: section == :superseded ? Array(metadata['successor_ids']).map(&:to_s) : [] }
      end
    end

    def section_label
      self.class::SECTIONS.fetch(section)
    end

    def admin_user?
      ChangeSource.admin_user?(changed_by)
    end

    def source
      ChangeSource.label(changed_by)
    end

    def summary
      ChangeLineFormatter.format_line(to_h)
    end
  end
end
