namespace :green_lanes do
  desc 'Convert a CSV of the categorisation data to JSON format CSVFILE=path/to/file.csv'
  task generate_categorisation_data: :environment do
    raise "Cannot read file '#{ENV['CSVFILE']}'" unless File.file?(ENV['CSVFILE'].to_s)

    @data = CSV.read(ENV['CSVFILE'], headers: true)
    @json = @data.map do |row|
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

    path = Rails.root.join('data/green_lanes').to_s
    Dir.mkdir path unless Dir.exist? path

    Rails.root.join('data/green_lanes/categories.json').write \
      JSON.pretty_generate(@json)
  end

  desc 'Import Themes data'
  task import_themes: :environment do
    raise 'Not in XI environment' unless TradeTariffBackend.xi?

    source_file = Rails.root.join('data/green_lanes/themes.csv')
    raise "Cannot read file '#{source_file}'" unless File.file?(source_file)

    @existing_themes = GreenLanes::Theme.all.index_by { |t| [t.section, t.subsection] }

    GreenLanes::Theme.db.transaction do
      CSV.foreach(source_file, headers: true) do |row|
        section, theme = row['Theme'].split(' ', 2)
        theme = theme.strip
        section = section.strip.gsub(/^(\d+\.\d+)\./, '\1')
        section, subsection = section.split('.').map(&:to_i)

        instance = @existing_themes[[section, subsection]]
        instance ||= GreenLanes::Theme.new(section:, subsection:)
        instance.theme = theme
        instance.description = row['Full description']
        instance.category = row['Category implied']
        instance.save(raise_on_failure: true)
      end
    end
  end
end
