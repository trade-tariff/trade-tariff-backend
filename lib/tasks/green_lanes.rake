module GreenLanesTasks
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
    GreenLanes::CategorisationDataGenerator.call
  end

  desc 'Import Themes data'
  task import_themes: :environment do
    GreenLanes::ThemeImporter.call
  end

  desc 'Import CategoryAssessments data'
  task import_category_assessments: :environment do
    GreenLanesTasks.import_category_assessments
  end

  desc 'Import Trade Remedies CategoryAssessments data'
  task import_tr_category_assessments: :environment do
    GreenLanesTasks.import_tr_category_assessments
  end

  desc 'Add pseudo measures PSEUDO_MEASURE_CSV_FILE=path/to/file.csv'
  task add_pseudo_measures: :environment do
    GreenLanesTasks.add_pseudo_measures
  end

  desc 'Add CategoryAssessments CATEGORY_ASSESSMENT_CSV_FILE=path/to/file.csv'
  task import_csv_category_assessments: :environment do
    GreenLanesTasks.import_csv_category_assessments
  end
end
