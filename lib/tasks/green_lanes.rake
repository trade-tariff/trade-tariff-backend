module GreenLanesCategorisationTasks
module_function

  def generate_categorisation_data
    raise "Cannot read file '#{ENV['CSVFILE']}'" unless File.file?(ENV['CSVFILE'].to_s)

    data = CSV.read(ENV['CSVFILE'], headers: true)
    json = data.map { |row| categorisation_data(row) }
    path = Rails.root.join('data/green_lanes').to_s
    Dir.mkdir path unless Dir.exist? path

    Rails.root.join('data/green_lanes/categories.json').write JSON.pretty_generate(json)
  end

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

module GreenLanesThemeTasks
module_function

  def import_themes
    raise 'Not in XI environment' unless TradeTariffBackend.xi?

    source_file = Rails.root.join('data/green_lanes/themes.html')
    raise "Cannot read file '#{source_file}'" unless File.file?(source_file)

    existing_themes = GreenLanes::Theme.all.index_by { |theme| [theme.section, theme.subsection] }

    GreenLanes::Theme.db.transaction do
      import_theme_nodes(Nokogiri::HTML(source_file.open), existing_themes)
    end
  end

  def import_theme_nodes(source_doc, existing_themes)
    section = nil
    source_doc.css('div#anx_IV p.oj-ti-grseq-1,div#anx_IV table').each do |node|
      section = import_theme_node(node, section, existing_themes)
    end
  end

  def import_theme_node(node, section, existing_themes)
    case node.name
    when 'p'
      node.content.strip.gsub(/Category /, '').to_i
    when 'table'
      import_theme_table(node, section, existing_themes)
      section
    else
      puts 'Unknown element, skipping'
      section
    end
  end

  def import_theme_table(node, section, existing_themes)
    cells = node.css('td')
    subsection = cells[0].content.strip.gsub(/\.$/, '').to_i
    description = cells[1].content.strip
    instance = existing_themes[[section, subsection]] || GreenLanes::Theme.new(section:, subsection:)

    instance.theme = description.slice(0, 254)
    instance.description = description
    instance.category = section
    instance.save(raise_on_failure: true)
  end
end

module GreenLanesCategoryAssessmentTasks
module_function

  def import_category_assessments
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    themes = GreenLanes::Theme.all.index_by { |theme| [theme.section, theme.subsection] }
    assessments = GreenLanes::CategoryAssessment.all.index_by { |assessment| category_assessment_key(assessment) }

    GreenLanes::CategoryAssessment.db.transaction do
      GreenLanes::CategoryAssessmentJson.all.each do |json_ca|
        import_category_assessment(json_ca, themes, assessments)
      end
    end
  end

  def category_assessment_key(assessment)
    [assessment.measure_type_id, assessment.regulation_id]
  end

  def import_category_assessment(json_ca, themes, assessments)
    return if json_ca.category.to_s == '3'
    return puts "MISSING THEME, SKIPPING: #{json_ca.inspect}" if json_ca.theme.blank?

    key = [json_ca.measure_type_id, json_ca.regulation_id]
    assessment = assessments[key] || build_category_assessment(json_ca)
    theme = category_assessment_theme(json_ca, themes)

    if assessment.id.nil?
      assessment.theme = theme
      assessment.save(validate: true)
    elsif assessment.theme != theme
      raise 'Inconsistent theme'
    end

    assessments[key] = assessment
  end

  def build_category_assessment(json_ca)
    assessment = GreenLanes::CategoryAssessment.new
    assessment.measure_type_id = json_ca.measure_type_id
    assessment.regulation_id = json_ca.regulation_id
    regulation = ModificationRegulation.actual.where(modification_regulation_id: json_ca.regulation_id).all.last
    regulation ||= BaseRegulation.actual.where(base_regulation_id: json_ca.regulation_id).all.last
    assessment.regulation_role = regulation&.role || 1
    assessment
  end

  def category_assessment_theme(json_ca, themes)
    section, subsection, theme_name = json_ca.theme.split('.', 3)
    theme_key = [section.to_i, subsection.to_i]
    themes[theme_key] ||= build_theme(section, subsection, json_ca.category, theme_name)
  end

  def build_theme(section, subsection, category, theme_name)
    GreenLanes::Theme.new.tap do |theme|
      theme.section = section
      theme.subsection = subsection
      theme.category = category
      theme.theme = theme_name
      theme.description = theme_name
      theme.save(validate: true)
    end
  end

  def import_tr_category_assessments
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    theme = GreenLanes::Theme.where(section: '1', subsection: '3').first
    assessments = GreenLanes::CategoryAssessment.all.index_by { |assessment| trade_remedies_assessment_key(assessment) }

    GreenLanes::CategoryAssessment.db.transaction do
      trade_remedies_measures.each do |trade_remedy|
        import_trade_remedies_assessment(trade_remedy, theme, assessments)
      end
    end
  end

  def trade_remedies_assessment_key(assessment)
    [assessment.measure_type_id, assessment.regulation_id, assessment.regulation_role]
  end

  def trade_remedies_measures
    types = %w[551 552 553 554 555 561 562 564 565 566 570 690 695 696]

    Measure.where(measure_type_id: types)
           .with_generating_regulation
           .select_group(:measure_type_id, :measure_generating_regulation_id, :measure_generating_regulation_role)
           .all
  end

  def import_trade_remedies_assessment(trade_remedy, theme, assessments)
    key = [trade_remedy.measure_type_id, trade_remedy.measure_generating_regulation_id, trade_remedy.measure_generating_regulation_role]
    assessment = assessments[key] || build_trade_remedies_assessment(trade_remedy)

    if assessment.id.nil?
      assessment.theme = theme
      assessment.save(validate: true)
    end

    assessments[key] = assessment
  end

  def build_trade_remedies_assessment(trade_remedy)
    assessment = GreenLanes::CategoryAssessment.new
    assessment.measure_type_id = trade_remedy.measure_type_id
    assessment.regulation_id = trade_remedy.measure_generating_regulation_id
    assessment.regulation_role = trade_remedy.measure_generating_regulation_role
    assessment
  end
end

module GreenLanesCsvAssessmentTasks
module_function

  def add_pseudo_measures
    pseudo_measure_data.each { |row| add_pseudo_measure(row) }
  end

  def pseudo_measure_data
    return s3_csv('data/categorisation/pseudo_measures.csv') if Rails.application.config.persistence_bucket.present?

    csv_file = ENV['PSEUDO_MEASURE_CSV_FILE']
    raise "Cannot read file '#{csv_file}'" unless File.file?(csv_file.to_s)

    CSV.read(csv_file, headers: true)
  end

  def add_pseudo_measure(row)
    goods_nomenclature = GoodsNomenclature.actual.where(goods_nomenclature_item_id: row['goods_nomenclature_item_id'],
                                                        producline_suffix: row['productline_suffix'])
    return if goods_nomenclature.blank?

    measure = GreenLanes::Measure.new
    measure.category_assessment_id = row['category_assessment_id']
    measure.goods_nomenclature_item_id = row['goods_nomenclature_item_id']
    measure.productline_suffix = row['productline_suffix']
    measure.save(validate: true)
  rescue Sequel::ValidationFailed
    nil
  end

  def import_csv_category_assessments
    raise 'Only supported on XI service' unless TradeTariffBackend.xi?

    csv_category_assessment_data.each { |row| import_csv_category_assessment(row) }
  end

  def csv_category_assessment_data
    if Rails.application.config.persistence_bucket.present?
      s3_csv('data/categorisation/category_assessment.csv')
    else
      local_category_assessment_csv
    end
  end

  def local_category_assessment_csv
    csv_file = ENV['CATEGORY_ASSESSMENT_CSV_FILE']
    raise "Cannot read file '#{csv_file}'" unless File.file?(csv_file.to_s)

    CSV.read(csv_file, headers: true)
  end

  def s3_csv(object_key)
    csv = Rails.application.config.persistence_bucket.object(object_key).get.body.read
    CSV.parse(csv, headers: true)
  rescue Aws::S3::Errors::NoSuchKey => e
    raise InvalidFile, "File not found in S3 (#{e.message})"
  end

  def import_csv_category_assessment(row)
    theme = GreenLanes::Theme.where(section: row['theme_section'], subsection: row['theme_subsection']).first
    assessments = GreenLanes::CategoryAssessment.all.index_by do |assessment|
      [assessment.measure_type_id, assessment.regulation_id, assessment.theme_id]
    end
    key = [row['measure_type_id'], row['regulation_id'], theme.id]
    assessment = assessments[key] || build_csv_category_assessment(row)

    save_csv_category_assessment(assessment, theme, row) if assessment.id.nil?
    assessments[key] = assessment
  end

  def build_csv_category_assessment(row)
    assessment = GreenLanes::CategoryAssessment.new
    assessment.measure_type_id = row['measure_type_id']
    assessment.regulation_id = row['regulation_id']
    assessment.regulation_role = row['regulation_role']
    assessment
  end

  def save_csv_category_assessment(assessment, theme, row)
    assessment.theme = theme
    assessment.save(validate: true)

    exemption = GreenLanes::Exemption.where(code: row['exemption_code']).first
    assessment.add_exemption(exemption) if exemption
  end
end

namespace :green_lanes do
  desc 'Convert a CSV of the categorisation data to JSON format CSVFILE=path/to/file.csv'
  task generate_categorisation_data: :environment do
    GreenLanesCategorisationTasks.generate_categorisation_data
  end

  desc 'Import Themes data'
  task import_themes: :environment do
    GreenLanesThemeTasks.import_themes
  end

  desc 'Import CategoryAssessments data'
  task import_category_assessments: :environment do
    GreenLanesCategoryAssessmentTasks.import_category_assessments
  end

  desc 'Import Trade Remedies CategoryAssessments data'
  task import_tr_category_assessments: :environment do
    GreenLanesCategoryAssessmentTasks.import_tr_category_assessments
  end

  desc 'Add pseudo measures PSEUDO_MEASURE_CSV_FILE=path/to/file.csv'
  task add_pseudo_measures: :environment do
    GreenLanesCsvAssessmentTasks.add_pseudo_measures
  end

  desc 'Add CategoryAssessments CATEGORY_ASSESSMENT_CSV_FILE=path/to/file.csv'
  task import_csv_category_assessments: :environment do
    GreenLanesCsvAssessmentTasks.import_csv_category_assessments
  end
end
