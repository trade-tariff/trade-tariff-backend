module ViewService
  def self.refresh_materialized_views!(concurrently: false)
    GoodsNomenclatures::TreeNode.refresh!(concurrently:)
    GeographicalAreaMembership.refresh!
  end
end
