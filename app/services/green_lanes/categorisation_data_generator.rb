require 'csv'

module GreenLanes
  class CategorisationDataGenerator
    class << self
      def call
        raise "Cannot read file '#{ENV['CSVFILE']}'" unless File.file?(ENV['CSVFILE'].to_s)

        data = CSV.read(ENV['CSVFILE'], headers: true)
        json = data.map { |row| categorisation_data(row) }
        path = Rails.root.join('data/green_lanes').to_s
        Dir.mkdir path unless Dir.exist? path

        Rails.root.join('data/green_lanes/categories.json').write JSON.pretty_generate(json)
      end

    private

      def categorisation_data(row)
        {
          category: row['Primary category'],
          regulation_id: row['Regulation id'].presence&.strip,
          measure_type_id: row['Measure type ID'].presence&.strip,
          geographical_area_id: row['Geographical area']&.presence&.strip,
          document_codes: row['Document codes'].to_s.split.map(&:strip),
          additional_codes: row['Additional codes'].to_s.split.map(&:strip),
          theme: row['Theme'].to_s.strip,
        }
      end
    end
  end
end
