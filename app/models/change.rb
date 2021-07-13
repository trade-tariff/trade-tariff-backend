class Change < Sequel::Model
  plugin :time_machine

  def self.cleanup(older_than: Date.current.ago(3.months))
    where('change_date < ?', older_than).delete
  end
end
