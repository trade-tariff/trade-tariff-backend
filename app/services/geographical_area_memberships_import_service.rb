require 'csv'

class GeographicalAreaMembershipsImportService
  attr_accessor :errors

  def initialize
    @errors = []
  end

  def import_hjids(filename)
    CSV.foreach(filename, headers: true) do |row|
      update_geographical_area(row)
    end
  end

  def import_hjids_stats
    {
      geographical_areas_total: GeographicalAreaMembership.count,
      geographical_areas_with_hjid_total: GeographicalAreaMembership.exclude(hjid: nil).count,
      errors: errors.count,
    }
  end

  private

  def update_geographical_area(row)
    geographical_area_membership = GeographicalAreaMembership[
      geographical_area_sid: row[2].to_i,
      geographical_area_group_sid: row[4].to_i,
      validity_start_date: row[5]
    ]

    if geographical_area_membership.present?
      geographical_area_membership.hjid = row[0].to_i
      geographical_area_membership.geographical_area_hjid = row[1].to_i
      geographical_area_membership.geographical_area_group_hjid = row[3].to_i
      geographical_area_membership.save
    else
      Rails.logger.info("Failed to find matching geographical area membership for geographical_area_sid: #{row[2]}, geographical_area_group_sid: #{row[4]}, validity_start_date: #{row[5]} \n")
      errors << row
    end
  end
end
