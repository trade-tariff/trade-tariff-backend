module GreenLanesUpdatesPublisher
  class DataUpdatesFinder
    DB = Sequel::Model.db

    def initialize(date = Time.zone.today)
      @start_date = date
    end

    def call
      all_updates = []
      updates = fetch_updates(base_regulations)
      updates.each { |update| all_updates.push(update) }

      updates = fetch_updates(modification_regulations)
      updates.each { |update| all_updates.push(update) }
      all_updates
    end

    private

    def fetch_updates(query)
      dataset = DB.fetch(query, @start_date, @start_date)
      dataset.map { |row| GreenLanesUpdate.new(row[:regulation_id], row[:regulation_role], row[:measure_type_id]) }
    end

    def base_regulations
      "select br.base_regulation_id as regulation_id, br.base_regulation_role as regulation_role, mo.measure_type_id
      from base_regulations_oplog br
      inner join measures_oplog mo
      on br.base_regulation_id = mo.measure_generating_regulation_id and br.base_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where br.created_at > ? or mo.created_at > ?
      group by(br.base_regulation_id, br.base_regulation_role, mo.measure_type_id)"
    end

    def modification_regulations
      "select mr.modification_regulation_id as regulation_id, mr.modification_regulation_role as regulation_role, mo.measure_type_id
      from modification_regulations_oplog mr
      inner join measures_oplog mo
      on mr.modification_regulation_id  = mo.measure_generating_regulation_id and mr.modification_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where mr.created_at > ? or mo.created_at > ?
      group by(mr.modification_regulation_id, mr.modification_regulation_role, mo.measure_type_id)"
    end
  end
end
