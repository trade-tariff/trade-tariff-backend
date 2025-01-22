module ApplicationHelper
  def regulation_url(regulation)
    ApplicationHelper.regulation_url(regulation)
  end

  def self.regulation_url(regulation)
    MeasureService::CouncilRegulationUrlGenerator.new(
      regulation,
    ).generate
  end

  def regulation_code(regulation)
    ApplicationHelper.regulation_code(regulation)
  end

  def self.regulation_code(regulation)
    regulation_id = regulation.regulation_id
    "#{regulation_id.first}#{regulation_id[3..6]}/#{regulation_id[1..2]}"
  end
end
