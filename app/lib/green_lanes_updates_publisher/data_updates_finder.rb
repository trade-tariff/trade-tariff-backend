module GreenLanesUpdatesPublisher
  class DataUpdatesFinder
    DB = Sequel::Model.db

    attr_reader :start_date

    BASE_REGULATIONS = <<~SQL.squish.freeze
      SELECT
        br.base_regulation_id AS regulation_id,
        br.base_regulation_role AS regulation_role,
        mo.measure_type_id,
        #{::GreenLanes::UpdateNotification::NotificationStatus::CREATED} AS status
      FROM base_regulations_oplog br
      INNER JOIN measures_oplog mo
        ON br.base_regulation_id = mo.measure_generating_regulation_id
        AND br.base_regulation_role = mo.measure_generating_regulation_role
      INNER JOIN measure_types mt
        ON mo.measure_type_id = mt.measure_type_id
        AND mt.trade_movement_code IN (0, 1)
      WHERE br.created_at > :today OR mo.created_at > :today
      GROUP BY br.base_regulation_id, br.base_regulation_role, mo.measure_type_id
    SQL

    MODIFICATION_REGULATIONS = <<~SQL.squish.freeze
      SELECT
        mr.modification_regulation_id AS regulation_id,
        mr.modification_regulation_role AS regulation_role,
        mo.measure_type_id,
        #{::GreenLanes::UpdateNotification::NotificationStatus::CREATED} AS status
      FROM modification_regulations_oplog mr
      INNER JOIN measures_oplog mo
        ON mr.modification_regulation_id = mo.measure_generating_regulation_id
        AND mr.modification_regulation_role = mo.measure_generating_regulation_role
      INNER JOIN measure_types mt
        ON mo.measure_type_id = mt.measure_type_id
        AND mt.trade_movement_code IN (0, 1)
      WHERE mr.created_at > :today OR mo.created_at > :today
      GROUP BY mr.modification_regulation_id, mr.modification_regulation_role, mo.measure_type_id
    SQL

    EXPIRED_BASE_REGULATIONS = <<~SQL.squish.freeze
      SELECT
        br.base_regulation_id AS regulation_id,
        br.base_regulation_role AS regulation_role,
        mo.measure_type_id,
        #{::GreenLanes::UpdateNotification::NotificationStatus::EXPIRED} AS status
      FROM base_regulations_oplog br
      INNER JOIN measures_oplog mo
        ON br.base_regulation_id = mo.measure_generating_regulation_id
        AND br.base_regulation_role = mo.measure_generating_regulation_role
      INNER JOIN measure_types mt
        ON mo.measure_type_id = mt.measure_type_id
        AND mt.trade_movement_code IN (0, 1)
      WHERE LEAST(br.validity_end_date, br.effective_end_date) BETWEEN :yesterday AND :today
        OR mo.validity_end_date BETWEEN :yesterday AND :today
      GROUP BY br.base_regulation_id, br.base_regulation_role, mo.measure_type_id
    SQL

    EXPIRED_MODIFICATION_REGULATIONS = <<~SQL.squish.freeze
      SELECT
        mr.modification_regulation_id AS regulation_id,
        mr.modification_regulation_role AS regulation_role,
        mo.measure_type_id,
        #{::GreenLanes::UpdateNotification::NotificationStatus::EXPIRED} AS status
      FROM modification_regulations_oplog mr
      INNER JOIN measures_oplog mo
        ON mr.modification_regulation_id = mo.measure_generating_regulation_id
        AND mr.modification_regulation_role = mo.measure_generating_regulation_role
      INNER JOIN measure_types mt
        ON mo.measure_type_id = mt.measure_type_id
        AND mt.trade_movement_code IN (0, 1)
      WHERE LEAST(mr.validity_end_date, mr.effective_end_date) BETWEEN :yesterday AND :today
        OR mo.validity_end_date BETWEEN :yesterday AND :today
      GROUP BY mr.modification_regulation_id, mr.modification_regulation_role, mo.measure_type_id
    SQL

    UPDATED_MEASURES = <<~SQL.squish.freeze
      SELECT
        mo.measure_generating_regulation_id AS regulation_id,
        mo.measure_generating_regulation_role AS regulation_role,
        mo.measure_type_id,
        #{::GreenLanes::UpdateNotification::NotificationStatus::UPDATED} AS status
      FROM measures_oplog mo
      LEFT JOIN measure_conditions_oplog mc
        ON mo.measure_sid = mc.measure_sid
      LEFT JOIN additional_codes_oplog ac
        ON mo.additional_code_sid = ac.additional_code_sid
      LEFT JOIN measure_excluded_geographical_areas_oplog ga
        ON mo.measure_sid = ga.measure_sid
      INNER JOIN measure_types mt
        ON mo.measure_type_id = mt.measure_type_id
        AND mt.trade_movement_code IN (0, 1)
      WHERE mc.created_at > :today OR ac.created_at > :today OR ga.created_at > :today
      GROUP BY mo.measure_generating_regulation_id, mo.measure_generating_regulation_role, mo.measure_type_id
    SQL

    def initialize(start_date = Time.zone.today)
      @start_date = start_date
    end

    def call
      queries = [
        BASE_REGULATIONS,
        MODIFICATION_REGULATIONS,
        EXPIRED_BASE_REGULATIONS,
        EXPIRED_MODIFICATION_REGULATIONS,
        UPDATED_MEASURES,
      ]

      queries.flat_map { |query| fetch_updates(query) }
    end

    private

    def fetch_updates(query)
      dataset = DB.fetch(
        query,
        today: start_date,
        yesterday: start_date - 1.day,
      )

      dataset.map do |row|
        GreenLanesUpdate.new(
          row[:regulation_id],
          row[:regulation_role],
          row[:measure_type_id],
          row[:status],
        )
      end
    end
  end
end
