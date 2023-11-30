namespace :green_lanes do
  desc 'Convert a CSV of the categorisation data to JSON format CSVFILE=path/to/file.csv'
  task generate_categorisation_data: :environment do
    raise "Cannot read file '#{ENV['CSVFILE']}'" unless File.file?(ENV['CSVFILE'].to_s)

    @data = CSV.read(ENV['CSVFILE'], headers: true)
    @json = @data.map do |row|
      {
        category: row['Primary category'],
        constraints: {
          regulation_id: row['Regulation id'].presence.strip,
          measure_type_id: row['Measure type ID'].presence.strip,
          geographical_area: row['Geographical area']&.presence&.strip,
          document_codes: row['Document codes'].to_s.split.map(&:strip),
          additional_codes: row['Additional codes'].to_s.split.map(&:strip),
        },
      }
    end

    Rails.root.join('data/green_lanes/categories.json').write \
      JSON.pretty_generate(@json)
  end
end
