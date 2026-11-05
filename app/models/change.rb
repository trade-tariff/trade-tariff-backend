class Change < Sequel::Model
  # Number of changes to fetch for a commodity, heading or chapter
  RECENT_LIMIT = 10

  plugin :time_machine

  def self.cleanup(older_than: 3.months.ago.beginning_of_day)
    where('change_date < ?', older_than).delete
  end
end
