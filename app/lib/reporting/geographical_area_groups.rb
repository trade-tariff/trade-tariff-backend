module Reporting
  class GeographicalAreaGroups
    extend Reporting::Reportable

    HEADER_ROW = %w[
      parent_id
      parent_description
      child_id
      child_description
    ].freeze

    COLUMN_WIDTHS = [
      20, # parent_id
      75, # parent_description
      20, # child_id
      75, # child_description
    ].freeze

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
        workbook = if Rails.env.development?
                     FileUtils.rm(filename) if File.exist?(filename)

                     FastExcel.open(
                       filename,
                       constant_memory: true,
                     )
                   else
                     FastExcel.open(
                       constant_memory: true,
                     )
                   end
        bold_format = workbook.add_format(bold: true)

        worksheet = workbook.add_worksheet(Time.zone.today.iso8601)

        COLUMN_WIDTHS.each_with_index do |width, index|
          worksheet.set_column_width(index, width)
        end

        worksheet.append_row(HEADER_ROW, bold_format)
        worksheet.freeze_panes(1, 0)
        worksheet.autofilter(0, 1, 1, 4)

        each_geographical_area_group_and_child do |group, child|
          row = build_row_for(group, child)
          worksheet.append_row(row)
        end

        workbook.close

        if Rails.env.production?
          object.put(
            body: workbook.read_string,
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

      def filename
        File.basename(object_key)
      end
    end
  end
end
