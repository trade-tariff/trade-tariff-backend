module GeneratedContentLifecycle
  def mark_needs_review!
    update(needs_review: true, approved: false)
  end

  def approve!
    update(needs_review: false, approved: true)
  end

  def assign_manual_edit(attributes)
    set(manual_edit_attributes(attributes))
  end

  def apply_manual_edit!(attributes)
    update(manual_edit_attributes(attributes))
  end

  def apply_pipeline_generation!(attributes)
    return false if manually_edited

    update(generated_attributes(attributes))
    true
  end

  def apply_ui_regeneration!(attributes)
    update(generated_attributes(attributes))
  end

  def prepare_ui_regeneration!(attributes)
    update(
      attributes.merge(
        stale: false,
        manually_edited: false,
        needs_review: false,
        approved: false,
      ),
    )
  end

  def mark_stale!
    update(stale: true)
  end

  def mark_expired!
    update(expired: true)
  end

  private

  def manual_edit_attributes(attributes)
    attributes.merge(
      manually_edited: true,
      needs_review: false,
      approved: true,
    )
  end

  def generated_attributes(attributes)
    attributes.merge(
      stale: false,
      manually_edited: false,
      needs_review: false,
      approved: false,
    )
  end
end
