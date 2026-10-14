module Reporting
  # Monthly summary of search reference changes. The admin download and the email both use
  # the CSV that generate builds, so they always contain the same data.
  class SearchReferenceChanges
    include Reporting::Reportable

    SECTION_ORDER = SearchReferences::ChangeEntry::SECTIONS.keys.freeze

    ADMIN_USERS_SOURCE = 'Admin users'.freeze

    # breakdown lists [changed_by, count] pairs for the admin users group, otherwise it is empty.
    SourceCount = Data.define(:source, :count, :breakdown)

    Result = Data.define(:period, :entries, :csv_data, :filename) do
      def total
        entries.size
      end

      def no_changes?
        entries.empty?
      end

      def period_label
        period.begin.strftime('%B %Y')
      end

      # Non-empty sections in report order, as [section, entries] pairs.
      def sections
        grouped = entries.group_by(&:section)
        SECTION_ORDER.filter_map { |section| [section, grouped[section]] if grouped[section] }
      end

      def removed_count
        entries.count { |entry| SearchReferences::ChangeEntry::REMOVAL_SECTIONS.include?(entry.section) }
      end

      # Counts per readable source, largest first. All admin users are one group.
      def counts_by_source
        entries
          .group_by { |entry| entry.admin_user? ? ADMIN_USERS_SOURCE : entry.source }
          .map { |source, group|
            breakdown = source == ADMIN_USERS_SOURCE ? count_desc(group.map(&:changed_by)) : []
            SourceCount.new(source:, count: group.size, breakdown:)
          }
          .sort_by { |source_count| [-source_count.count, source_count.source] }
      end

    private

      def count_desc(values)
        values.tally.sort_by { |value, count| [-count, value] }
      end
    end

    class << self
      def generate(period: default_period)
        with_report_logging do
          entries = instrument_report_step('load_rows') { load_entries(period) }

          log_report_metric('rows_written', entries.size)

          csv_data = instrument_report_step('serialize_csv', rows_written: entries.size) do
            Api::Admin::Csv::SearchReferenceChangeSerializer.new(entries).serialized_csv
          end

          log_report_metric('output_bytes', csv_data.bytesize)

          key = object_key(period)
          publish(csv_data, key)

          Result.new(period:, entries:, csv_data:, filename: File.basename(key))
        end
      end

      # The previous calendar month.
      def default_period
        last_month = now.prev_month
        last_month.beginning_of_month..last_month.end_of_month
      end

      def object_key(period = default_period)
        "#{service}/reporting/#{year}/#{month}/#{day}/search_reference_changes_#{service}_#{period.begin.strftime('%Y_%m')}.csv"
      end

    private

      def load_entries(period)
        versions = Version
          .by_item_type(SearchReference.name)
          .where(Sequel[:created_at] >= period.begin.beginning_of_day)
          .where(Sequel[:created_at] < period.end.next_day.beginning_of_day)
          .order(:created_at, :id)
          .all

        Version.preload_predecessors(versions)

        versions
          .map { |version| SearchReferences::ChangeEntry.from_version(version) }
          .sort_by.with_index { |entry, index| [SECTION_ORDER.index(entry.section), index] }
      end

      def publish(csv_data, key)
        if Rails.env.development?
          instrument_report_step('write_local_file', output_bytes: csv_data.bytesize) do
            File.write(File.basename(key), csv_data)
          end
        end

        if Rails.env.production?
          instrument_report_step('upload', output_bytes: csv_data.bytesize) do
            object(key).put(body: csv_data, content_type: 'text/csv')
          end
        end
      end
    end
  end
end
