class Apply < Sequel::Model
  private

  def validate
    must_have :user_id
  end

  def must_have(attribute)
    errors.add(attribute, "Can't be blank") if send(attribute).blank?
  end

  def after_create
    ApplyWorker.perform_async
  end

  def before_create
    self.enqueued_at = Time.zone.current
    super
  end
end
