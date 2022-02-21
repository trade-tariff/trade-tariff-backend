class Change < Sequel::Model
  plugin :time_machine

  def self.cleanup(older_than: 3.months.ago.beginning_of_day)
    where('change_date < ?', older_than).delete
  end
end
