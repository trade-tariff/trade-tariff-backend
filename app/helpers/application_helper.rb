module ApplicationHelper
  # Used in generating links in JSON responses
  #
  # Trade Tariff Frontend app proxies API requests to the
  # backend. We need to prefix the link /trade-tariff (which
  # is an app slug of tariff) so that users would receive
  # correct links
  def api_link(relative_link)
    "/trade-tariff#{relative_link}"
  end

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
