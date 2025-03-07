module Reporting
  class GeographicalAreaGroups
    extend Reporting::Reportable

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
        package = Axlsx::Package.new
        package.use_shared_strings = true
        workbook = package.workbook
        bold_style = workbook.styles.add_style(b: true)

        workbook.add_worksheet(name: Time.zone.today.iso8601) do |sheet|
          sheet.add_row(HEADER_ROW, style: bold_style)
          sheet.auto_filter = AUTOFILTER_CELL_RANGE
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
            pane.state = :frozen
            pane.y_split = 1
          end

          each_geographical_area_group_and_child do |group, child|
            row = build_row_for(group, child)
            sheet.add_row(row, types: CELL_TYPES)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        package.serialize('geographical_area_groups.xlsx') if Rails.env.development?

        if Rails.env.production?
          object.put(
            body: package.to_stream.read,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
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
        "#{service}/reporting/#{year}/#{month}/#{day}/geographical_area_groups_#{service}_#{now.strftime('%Y_%m_%d')}.xlsx"
      end
    end
  end
end
