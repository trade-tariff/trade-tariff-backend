module TariffSynchronizer
  class CdsUpdateReporter
    # Fetch gzip file from S3
    # Unzip file to xml file
    # Parse xml -> handled by CdsImporter

    # Create excel report
    # Save report to S3
    # Mail report to hmrc

    # TODO: Check if there's already a report for this day? Does this happen anywhere else?
    REPORABLE_CDS_ENTITIES = [
      'QuotaOrderNumber',
      'Measure',
      'Footnote',
    ].freeze

    DATE_KEYS = [
      'validityStartDate',
      'validityEndDate',
      ].freeze

    def initialize(entities)
      # what if it's empty? in the import somwhere it checks but I don't remember where and if it's before the import or after
      @reportable_entities = entities.flat_map do |mapped_entity|
        mapped_entity.select { |entity| REPORABLE_CDS_ENTITIES.include?(entity.entity_class) }
      end
    end

    def generate
      package = Axlsx::Package.new
      workbook = package.workbook

      @reportable_entities.each do |entity|

        puts "Processing #{entity.entity_class}"

        keys =
          if entity.reportable_entity_mapping.nil?
            entity.mapping_with_key_as_array.keys
          else
            entity.mapping_reportable_with_key_as_array.keys
          end

        headers = entity.reportable_entity_mapping.values

        existing_sheet = workbook.worksheets.find { |sheet| sheet.name == entity.entity_class }

        worksheet = existing_sheet ||
        workbook.add_worksheet(name: entity.entity_class) do |sheet|
          bold = workbook.styles.add_style(b: true)
          sheet.add_row headers, style: Array.new(headers.size, bold)
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = 'A2'
            pane.state = :frozen_split
            pane.y_split = 1
          end
        end

            data = keys.map { |path| entity.xml_node.dig(*path) }
            puts "keys: #{keys}, data: #{data}"
            worksheet.add_row(data)

          worksheet.column_widths(*Array.new(headers.size, 30))

        io = package.to_stream
        File.open("tmp/report.xlsx", "wb") { |f| f.write(io.read) }
      end
    end

    private

    def operation_mapping(entity_class)
      {
        'C' => "Create a new #{entity_class}",
        'U' => "Update an existing #{entity_class}",
        'D' => "Delete a #{entity_class}",
      }
    end
  end
end
