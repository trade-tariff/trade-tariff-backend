class Apply < Sequel::Model
private

  def validate
    must_have :whodunnit
  end

  def must_have(attribute)
    errors.add(attribute, "Can't be blank") if send(attribute).blank?
  end

  def before_create
    self.enqueued_at = Time.zone.now
    super
  end
end
