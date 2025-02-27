module GreenLanesUpdatesPublisher
  class DataUpdatesFinder
    DB = Sequel::Model.db

    # Today date is passed in YYYY-MM-DD 00:00:00.000000+0000 format, which is the zeroth minute of the day.
    # This will fetch all the recorded created by the data sync job which runs before this job as the created date
    # added with exact time. Created data will always be greater than the zeroth minute timestamp of the same day
    BASE_REGULATIONS =
      "select br.base_regulation_id as regulation_id, br.base_regulation_role as regulation_role, mo.measure_type_id,
      #{::GreenLanes::UpdateNotification::NotificationStatus::CREATED} as status
      from base_regulations_oplog br
      inner join measures_oplog mo
      on br.base_regulation_id = mo.measure_generating_regulation_id and br.base_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where br.created_at > :today or mo.created_at > :today
      group by(br.base_regulation_id, br.base_regulation_role, mo.measure_type_id)".freeze

    MODIFICATION_REGULATIONS =
      "select mr.modification_regulation_id as regulation_id, mr.modification_regulation_role as regulation_role, mo.measure_type_id,
      #{::GreenLanes::UpdateNotification::NotificationStatus::CREATED} as status
      from modification_regulations_oplog mr
      inner join measures_oplog mo
      on mr.modification_regulation_id  = mo.measure_generating_regulation_id and mr.modification_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where mr.created_at > :today or mo.created_at > :today
      group by(mr.modification_regulation_id, mr.modification_regulation_role, mo.measure_type_id)".freeze

    EXPIRED_BASE_REGULATIONS =
      "select br.base_regulation_id as regulation_id, br.base_regulation_role as regulation_role, mo.measure_type_id,
      #{::GreenLanes::UpdateNotification::NotificationStatus::EXPIRED} as status
      from base_regulations_oplog br
      inner join measures_oplog mo
      on br.base_regulation_id = mo.measure_generating_regulation_id and br.base_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where least(br.validity_end_date, br.effective_end_date) between :yesterday and :today
            or mo.validity_end_date between :yesterday and :today
      group by(br.base_regulation_id, br.base_regulation_role, mo.measure_type_id)".freeze

    EXPIRED_MODIFICATION_REGULATIONS =
      "select mr.modification_regulation_id as regulation_id, mr.modification_regulation_role as regulation_role, mo.measure_type_id,
      #{::GreenLanes::UpdateNotification::NotificationStatus::EXPIRED} as status
      from modification_regulations_oplog mr
      inner join measures_oplog mo
      on mr.modification_regulation_id  = mo.measure_generating_regulation_id and mr.modification_regulation_role = mo.measure_generating_regulation_role
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where least(mr.validity_end_date, mr.effective_end_date) between :yesterday and :today
            or mo.validity_end_date between :yesterday and :today
      group by(mr.modification_regulation_id, mr.modification_regulation_role, mo.measure_type_id)".freeze

    UPDATED_MEASURES =
      "select mo.measure_generating_regulation_id as regulation_id, mo.measure_generating_regulation_role as regulation_role, mo.measure_type_id,
      #{::GreenLanes::UpdateNotification::NotificationStatus::UPDATED} as status
      from measures_oplog mo
      left join measure_conditions_oplog mc
      on mo.measure_sid = mc.measure_sid
      left join additional_codes_oplog ac
      on mo.additional_code_sid = ac.additional_code_sid
      left join measure_excluded_geographical_areas_oplog ga
      on mo.measure_sid = ga.measure_sid
      inner join measure_types mt
      on mo.measure_type_id = mt.measure_type_id and mt.trade_movement_code in (0,1)
      where mc.created_at > :today or ac.created_at > :today or ga.created_at > :today
      group by(mo.measure_generating_regulation_id, mo.measure_generating_regulation_role, mo.measure_type_id)".freeze

    def initialize(date = Time.zone.today)
      @start_date = date
    end

    def call
      all_updates = []
      update_types = [BASE_REGULATIONS, MODIFICATION_REGULATIONS, EXPIRED_BASE_REGULATIONS, EXPIRED_MODIFICATION_REGULATIONS, UPDATED_MEASURES]

      update_types.each do |update_type|
        updates = fetch_updates(update_type)
        updates.each { |update| all_updates.push(update) }
      end

      all_updates
    end

    private

    def fetch_updates(query)
      dataset = DB.fetch(query, today: @start_date, yesterday: @start_date - 1)
      dataset.map { |row| GreenLanesUpdate.new(row[:regulation_id], row[:regulation_role], row[:measure_type_id], row[:status]) }
    end
  end
end
