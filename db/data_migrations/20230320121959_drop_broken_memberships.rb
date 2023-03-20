Sequel.migration do
  up do
    memberships = [
      {
        geographical_area_sid: 186,
        geographical_area_group_sid: 520,
        filename: 'tariff_dailyExtract_v1_20230224T235959.gzip',
      },
      {
        geographical_area_sid: 248,
        geographical_area_group_sid: 520,
        filename: 'tariff_dailyExtract_v1_20230224T235959.gzip',
      },
    ]

    memberships.each do |membership|
      GeographicalAreaMembership.find(membership).destroy
    end
  end

  down do
    # Will not rollback
  end
end
