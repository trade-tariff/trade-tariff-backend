class CdsUpdateNotification < Sequel::Model
  dataset_module do
    def descending
      order(Sequel.desc(:id))
    end
  end

  one_to_one :cds_update, primary_key: :filename,
                          key: :filename,
                          class_name: TariffSynchronizer::CdsUpdate

  def validate
    super
    must_have :filename
    must_have :user_id

    errors.add(:filename, 'must refer to an existing CDS update') unless TariffSynchronizer::CdsUpdate.where(filename: filename).count.positive?
  end

  private

  def must_have(attribute)
    errors.add(attribute, "Can't be blank") if send(attribute).blank?
  end

  def after_create
    CdsUpdateNotificationWorker.perform_async(id)
  end

  def before_create
    self.enqueued_at = Time.current
    super
  end
end
