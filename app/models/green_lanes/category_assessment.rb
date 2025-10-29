module GreenLanes
  class CategoryAssessment < Sequel::Model(:green_lanes_category_assessments)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :association_pks
    plugin :association_dependencies
    plugin :touch

    many_to_one :theme
    many_to_one :measure_type, class: :MeasureType
    many_to_one :base_regulation, class: :BaseRegulation,
                                  key: %i[regulation_id regulation_role]
    many_to_one :modification_regulation, class: :ModificationRegulation,
                                          key: %i[regulation_id regulation_role]
    one_to_many :measures, class: :Measure,
                           read_only: true,
                           primary_key: %i[measure_type_id regulation_id regulation_role],
                           key: %i[measure_type_id
                                   measure_generating_regulation_id
                                   measure_generating_regulation_role] do |ds|
      ds.with_actual(::Measure)
        .with_regulation_dates_query
    end

    one_to_many :green_lanes_measures, class: 'Measure',
                                       class_namespace: 'GreenLanes',
                                       reciprocal: :category_assessment
    add_association_dependencies green_lanes_measures: :delete

    many_to_many :exemptions, join_table: :green_lanes_category_assessments_exemptions,
                              left_key: :category_assessment_id,
                              left_primary_key: :id,
                              right_key: :exemption_id,
                              right_primary_key: :id,
                              use_optimized: true
    add_association_dependencies exemptions: :nullify

    dataset_module do
      def latest
        order(Sequel.desc(:updated_at)).first
      end
    end

    def validate
      super

      validates_presence :regulation_role
      validates_presence :regulation_id

      validates_unique %i[measure_type_id regulation_id regulation_role], where: (lambda do |ds, obj, _cols|
        if obj.regulation_id.blank?
          ds.where(measure_type_id: obj.measure_type_id)
        else
          ds.where(measure_type_id: obj.measure_type_id, regulation_id: nil, regulation_role: nil)
        end
      end)
    end

    def regulation
      case regulation_role
      when nil then nil
      when ::Measure::MODIFICATION_REGULATION_ROLE then modification_regulation
      else base_regulation
      end
    end

    def regulation=(regulation)
      case regulation
      when nil
        self.base_regulation = self.modification_regulation = nil
      when ModificationRegulation
        self.base_regulation = nil
        self.modification_regulation = regulation
      else
        self.modification_regulation = nil
        self.base_regulation = regulation
      end
    end

    def combined_measures
      measures.select(&:import) + active_green_lanes_measures
    end

    def active_green_lanes_measures
      green_lanes_measures.select(&:goods_nomenclature)
    end
  end
end
