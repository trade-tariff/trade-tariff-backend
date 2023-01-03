Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    area = GeographicalAreaMembership.where(
      geographical_area_sid: 107,
      geographical_area_group_sid: 504,
      validity_start_date: '2021-01-01T00:00:00.000Z',
      validity_end_date: nil,
      national: false,
      operation: 'C',
      operation_date: '2022-06-22',
      filename: 'tariff_dailyExtract_v1_20220622T235959.gzip',
      hjid: 11_901_227,
      geographical_area_hjid: nil,
      geographical_area_group_hjid: nil,
    ).first

    area && area.destroy
  end

  down do
    GeographicalAreaMembership.unrestrict_primary_key

    GeographicalAreaMembership.new(
      geographical_area_sid: 107,
      geographical_area_group_sid: 504,
      validity_start_date: '2021-01-01T00:00:00.000Z',
      validity_end_date: nil,
      national: false,
      operation: 'C',
      operation_date: '2022-06-22',
      filename: 'tariff_dailyExtract_v1_20220622T235959.gzip',
      hjid: 11_901_227,
      geographical_area_hjid: nil,
      geographical_area_group_hjid: nil,
    ).save
  end
end
