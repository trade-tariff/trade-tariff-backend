class MyottChange < Sequel::Model
  plugin :time_machine

  def self.cleanup(older_than: 3.months.ago.beginning_of_day)
    where('operation_date < ?', older_than).delete
  end
end
