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

  # TODO: Remove this and use the original path helpers once we're removed legacy routes which clobber the correct helpers
  def v1_api_path(resource, id = nil)
    service = TradeTariffBackend.service
    id = "/#{id}" if id

    "/#{service}/api/v1/#{resource}#{id}"
  end
end
