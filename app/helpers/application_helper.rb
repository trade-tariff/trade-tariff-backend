module ApplicationHelper
  delegate :regulation_url, to: :ApplicationHelper

  def self.regulation_url(regulation)
    MeasureService::CouncilRegulationUrlGenerator.new(
      regulation,
    ).generate
  end

  delegate :regulation_code, to: :ApplicationHelper

  def self.regulation_code(regulation)
    regulation_id = regulation.regulation_id
    "#{regulation_id.first}#{regulation_id[3..6]}/#{regulation_id[1..2]}"
  end
end
