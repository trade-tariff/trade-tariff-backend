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

    source_file = Rails.root.join('data/green_lanes/themes.html')
    raise "Cannot read file '#{source_file}'" unless File.file?(source_file)

    @existing_themes = GreenLanes::Theme.all.index_by { |t| [t.section, t.subsection] }

    GreenLanes::Theme.db.transaction do
      section = nil
      source_doc = Nokogiri::HTML(source_file.open)
      source_doc.css('div#anx_IV p.oj-ti-grseq-1,div#anx_IV table').each do |node|
        case node.name
        when 'p'
          section = node.content.strip.gsub(/Category /, '').to_i
        when 'table'
          cells = node.css('td')
          subsection = cells[0].content.strip.gsub(/\.$/, '').to_i
          description = cells[1].content.strip

          instance = @existing_themes[[section, subsection]]
          instance ||= GreenLanes::Theme.new(section:, subsection:)
          instance.theme = description.slice(0, 254)
          instance.description = description
          instance.category = section
          instance.save(raise_on_failure: true)
        else
          puts 'Unknown element, skipping'
        end
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

          regulation = ModificationRegulation.actual.where(modification_regulation_id: json_ca.regulation_id).all.last
          regulation ||= BaseRegulation.actual.where(base_regulation_id: json_ca.regulation_id).all.last

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

  desc 'Import Trade Remedies CategoryAssessments data'
  task import_tr_category_assessments: :environment do
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    # load existing data
    theme = GreenLanes::Theme.where(section: '1', subsection: '3').first
    assessments = GreenLanes::CategoryAssessment.all.index_by do |assessment|
      [assessment.measure_type_id, assessment.regulation_id, assessment.regulation_role]
    end
    types = %w[551 552 553 554 555 561 562 564 565 566 570 690 695 696]

    GreenLanes::CategoryAssessment.db.transaction do
      # select active measure_id, regulation_id and regulation_role of given measure type to create category_assessment
      Measure.where(measure_type_id: types)
             .actual.with_regulation_dates_query
             .select_group(:measure_type_id, :measure_generating_regulation_id, :measure_generating_regulation_role)
             .all.each do |tr|
        key = [tr.measure_type_id, tr.measure_generating_regulation_id, tr.measure_generating_regulation_role]
        assessment = assessments[key]

        unless assessment
          assessment = GreenLanes::CategoryAssessment.new
          assessment.measure_type_id = tr.measure_type_id
          assessment.regulation_id = tr.measure_generating_regulation_id
          assessment.regulation_role = tr.measure_generating_regulation_role
          assessments[key] = assessment
        end

        if assessment.id.nil?
          assessment.theme = theme
          assessment.save(validate: true)
        end

        assessments[key] = assessment
      end
    end
  end

  desc 'Add pseudo measures PSEUDO_MEASURE_CSV_FILE=path/to/file.csv'
  task add_pseudo_measures: :environment do
    if Rails.application.config.persistence_bucket.present?
      PSEUDO_MEASURE_CSV_OBJECT_KEY = 'data/categorisation/pseudo_measures.csv'.freeze
      begin
        csv = Rails.application.config.persistence_bucket.object(PSEUDO_MEASURE_CSV_OBJECT_KEY).get.body.read
        @data = CSV.parse(csv, headers: true)
      rescue Aws::S3::Errors::NoSuchKey => e
        raise InvalidFile, "File not found in S3 (#{e.message})"
      end
    else
      raise "Cannot read file '#{ENV['PSEUDO_MEASURE_CSV_FILE']}'" unless File.file?(ENV['PSEUDO_MEASURE_CSV_FILE'].to_s)

      @data = CSV.read(ENV['PSEUDO_MEASURE_CSV_FILE'], headers: true)
    end

    @data.map do |row|
      gn = GoodsNomenclature.actual.where(goods_nomenclature_item_id: row['goods_nomenclature_item_id'],
                                          producline_suffix: row['productline_suffix'])

      if gn.blank?
        next
      end

      measure = GreenLanes::Measure.new
      measure.category_assessment_id = row['category_assessment_id']
      measure.goods_nomenclature_item_id = row['goods_nomenclature_item_id']
      measure.productline_suffix = row['productline_suffix']

      begin
        measure.save(validate: true)
      rescue Sequel::ValidationFailed => e
        next
      end
    end
  end

  desc 'Add CategoryAssessments CATEGORY_ASSESSMENT_CSV_FILE=path/to/file.csv'
  task import_csv_category_assessments: :environment do
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    if Rails.application.config.persistence_bucket.present?
      CATEGORY_ASSESSMENT_CSV_OBJECT_KEY = 'data/categorisation/category_assessment.csv'.freeze
      begin
        csv = Rails.application.config.persistence_bucket.object(CATEGORY_ASSESSMENT_CSV_OBJECT_KEY).get.body.read
        @data = CSV.parse(csv, headers: true)
      rescue Aws::S3::Errors::NoSuchKey => e
        raise InvalidFile, "File not found in S3 (#{e.message})"
      end
    else
      raise "Cannot read file '#{ENV['CATEGORY_ASSESSMENT_CSV_FILE']}'" unless File.file?(ENV['CATEGORY_ASSESSMENT_CSV_FILE'].to_s)

      @data = CSV.read(ENV['CATEGORY_ASSESSMENT_CSV_FILE'], headers: true)
    end

    @data.map do |row|
      theme = GreenLanes::Theme.where(section: row['theme_section'], subsection: row['theme_subsection']).first
      assessments = GreenLanes::CategoryAssessment.all.index_by do |assessment|
        [assessment.measure_type_id, assessment.regulation_id, assessment.theme_id]
      end

      key = [row['measure_type_id'], row['regulation_id'], theme.id]
      assessment = assessments[key]

      unless assessment
        assessment = GreenLanes::CategoryAssessment.new
        assessment.measure_type_id = row['measure_type_id']
        assessment.regulation_id = row['regulation_id']
        assessment.regulation_role = row['regulation_role']
        assessments[key] = assessment
      end

      if assessment.id.nil?
        assessment.theme = theme
        assessment.save(validate: true)

        exemption = GreenLanes::Exemption.where(code: row['exemption_code']).first
        if exemption
          assessment.add_exemption(exemption)
        end
      end

      assessments[key] = assessment
    end
  end
end
