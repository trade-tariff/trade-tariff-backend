module GreenLanes
  class Theme < Sequel::Model(:green_lanes_themes)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    one_to_many :category_assessments
    plugin :touch, associations: %i[category_assessments]

    def to_s
      "#{code}. #{description}"
    end

    def code
      "#{section}.#{subsection}"
    end
  end
end
