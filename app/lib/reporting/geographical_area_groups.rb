module Reporting
  class GeographicalAreaGroups
    extend Reporting::Reportable
    extend Reporting::Spreadsheetable

    HEADER_ROW = %w[
      parent_id
      parent_description
      child_id
      child_description
    ].freeze

    CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

    COLUMN_WIDTHS = [
      20, # parent_id
      75, # parent_description
      20, # child_id
      75, # child_description
    ].freeze

    AUTOFILTER_CELL_RANGE = 'A1:D1'.freeze
    FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

    class PresentedGroup < WrapDelegator
      def parent_id
        geographical_area_id
      end

      def parent_description
        description
      end
    end

    class PresentedChild < WrapDelegator
      def child_id
        geographical_area_id
      end

      def child_description
        description
      end
    end

    class << self
      def generate
        package = create_spreadsheet do |sheet|
          each_geographical_area_group_and_child do |group, child|
            row = build_row_for(group, child)
            sheet.add_row(row, types: CELL_TYPES)
          end
        end

        save_document(object, object_key, package)
        log_query_count
      end

      private

      def build_row_for(group, child)
        HEADER_ROW.map do |header|
          if group.respond_to?(header)
            group.public_send(header)
          else
            child.public_send(header)
          end
        end
      end

      def each_geographical_area_group_and_child
        TimeMachine.now do
          GeographicalArea
            .groups
            .actual
            .eager(
              :geographical_area_descriptions,
              contained_geographical_areas: :geographical_area_descriptions,
            )
            .all
            .each do |group|
              group.contained_geographical_areas.each do |child|
                group = PresentedGroup.new(group)
                child = PresentedChild.new(child)

                yield group, child
              end
            end
        end
      end

      def object_key
        "#{object_key_prefix}/geographical_area_groups_#{object_key_suffix}.xlsx"
      end
    end
  end
end
