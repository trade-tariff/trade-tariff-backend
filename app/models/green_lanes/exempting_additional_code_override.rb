module GreenLanes
  class ExemptingAdditionalCodeOverride < Sequel::Model(:green_lanes_exempting_additional_code_overrides)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    one_to_one :reference_additional_code, class: :AdditionalCode,
                                           key: %i[additional_code_type_id additional_code],
                                           primary_key: %i[additional_code_type_id additional_code] do |ds|
      ds.with_actual(AdditionalCode)
    end

  private

    def after_create
      super
      touch_all_category_assessments
    end

    # Touch all of the model's touched_associations when destroying the object.
    def after_destroy
      super
      touch_all_category_assessments
    end

    # Touch all of the model's touched_associations when updating the object.
    def after_update
      super
      touch_all_category_assessments
    end

    def touch_all_category_assessments
      CategoryAssessment.dataset.update updated_at: Time.zone.now
    end
  end
end
