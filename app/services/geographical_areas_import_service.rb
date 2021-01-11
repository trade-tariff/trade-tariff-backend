require 'csv'

class GeographicalAreasImportService
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
      geographical_areas_total: GeographicalArea.count,
      geographical_areas_with_hjid_total: GeographicalArea.exclude(hjid: nil).count,
      errors: errors.count
    }
  end

  private

  def update_geographical_area(row)
    geographical_area = GeographicalArea[geographical_area_sid: row[1].to_i]
    if geographical_area.present?
      geographical_area.hjid = row[0].to_i
      geographical_area.save
    else
      print "Failed to find matching geographical area for geographical_area_sid: #{row[1]}\n"
      errors << row
    end
  end
end

