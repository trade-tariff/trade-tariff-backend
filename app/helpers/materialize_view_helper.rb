module MaterializeViewHelper
  def refresh_materialized_view(concurrently: false)
    GoodsNomenclatures::TreeNode.refresh!(concurrently:)
    GeographicalAreaMembership.refresh!(concurrently:)
    MeasureExcludedGeographicalArea.refresh!(concurrently:)
  end
end
