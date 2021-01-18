extends 'api/v1/commodities/commodity_base'

node(:children) { |commodity|
  commodity.children.map do |commodity|
    partial('api/v1/commodities/commodity', object: commodity)
  end
}
