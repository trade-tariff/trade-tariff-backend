extends 'api/v1/commodities/commodity_base'

node(:children) do |commodity|
  commodity.ns_children.map do |child_commodity|
    partial('api/v1/commodities/commodity', object: child_commodity)
  end
end
