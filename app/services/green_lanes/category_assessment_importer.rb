module GreenLanes
  class CategoryAssessmentImporter
    class << self
      def call(&missing_theme_handler)
        raise 'Only supported on XI service' unless TradeTariffBackend.xi?

        themes = GreenLanes::Theme.all.index_by { |theme| [theme.section, theme.subsection] }
        assessments = GreenLanes::CategoryAssessment.all.index_by { |assessment| category_assessment_key(assessment) }

        GreenLanes::CategoryAssessment.db.transaction do
          GreenLanes::CategoryAssessmentJson.all.each do |json_ca|
            import_category_assessment(json_ca, themes, assessments, missing_theme_handler)
          end
        end
      end

    private

      def category_assessment_key(assessment)
        [assessment.measure_type_id, assessment.regulation_id]
      end

      def import_category_assessment(json_ca, themes, assessments, missing_theme_handler)
        return if json_ca.category.to_s == '3'
        return missing_theme_handler&.call(json_ca) if json_ca.theme.blank?

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
    end
  end
end
