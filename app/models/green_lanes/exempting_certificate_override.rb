module GreenLanes
  class ExemptingCertificateOverride < Sequel::Model(:green_lanes_exempting_certificate_overrides)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    one_to_one :certificate, class: :Certificate,
                             key: %i[certificate_type_code certificate_code],
                             primary_key: %i[certificate_type_code certificate_code] do |ds|
      ds.with_actual(Certificate)
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
