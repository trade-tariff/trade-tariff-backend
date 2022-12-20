class Rollback < Sequel::Model
  dataset_module do
    def descending
      order(Sequel.desc(:id))
    end
  end

  private

  def validate
    must_have :reason
    must_have :user_id
    must_have_correct_date
  end

  def must_have_correct_date
    Date.parse(date) unless date.is_a?(Date)
  rescue ArgumentError, TypeError
    errors.add(:date, 'Incorrect date provided')
  end

  def must_have(attribute)
    errors.add(attribute, "Can't be blank") if send(attribute).blank?
  end

  def after_create
    RollbackWorker.perform_async(date.to_formatted_s(:db), keep)
  end

  def before_create
    self.enqueued_at = Time.current
    super
  end
end
