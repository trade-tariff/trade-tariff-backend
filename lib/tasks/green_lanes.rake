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

  desc 'Import CategoryAssessments data'
  task import_category_assessments: :environment do
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    # load existing data
    themes = GreenLanes::Theme.all.index_by { |t| [t.section, t.subsection] }
    assessments = GreenLanes::CategoryAssessment.all.index_by do |assessment|
      [assessment.measure_type_id, assessment.regulation_id]
    end

    GreenLanes::CategoryAssessment.db.transaction do
      GreenLanes::CategoryAssessmentJson.all.each do |json_ca|
        next if json_ca.category.to_s == '3'

        if json_ca.theme.blank?
          puts "MISSING THEME, SKIPPING: #{json_ca.inspect}"
          next
        end

        key = [json_ca.measure_type_id, json_ca.regulation_id]
        assessment = assessments[key]

        unless assessment
          assessment = GreenLanes::CategoryAssessment.new
          assessment.measure_type_id = json_ca.measure_type_id
          assessment.regulation_id = json_ca.regulation_id

          regulation = BaseRegulation.actual.where(base_regulation_id: json_ca.regulation_id).all.last
          regulation ||= ModificationRegulation.actual.where(base_regulation_id: json_ca.regulation_id).all.last

          assessment.regulation_role = regulation&.role || 1
          assessments[key] = assessment
        end

        section, subsection, theme_name = json_ca.theme.split('.', 3)
        theme_key = [section.to_i, subsection.to_i]
        themes[theme_key] ||= GreenLanes::Theme.new.tap do |theme|
          theme.section = section
          theme.subsection = subsection
          theme.category = json_ca.category
          theme.theme = theme_name
          theme.description = theme_name
          theme.save(validate: true)
        end

        if assessment.id.nil?
          assessment.theme = themes[theme_key]
          assessment.save(validate: true)
        elsif assessment.theme != themes[theme_key]
          raise 'Inconsistent theme'
        end

        assessments[key] = assessment
      end
    end
  end
end
