module MaterializeViewHelper
  def refresh_materialized_view(concurrently: false)
    GoodsNomenclatures::TreeNode.refresh!(concurrently:)
    GeographicalAreaMembership.refresh!(concurrently:)
    MeasureExcludedGeographicalArea.refresh!(concurrently:)
    GeographicalArea.refresh!(concurrently:)
    GeographicalAreaDescription.refresh!(concurrently:)
    GeographicalAreaDescriptionPeriod.refresh!(concurrently:)
    AdditionalCode.refresh!(concurrently:)
    AdditionalCodeType.refresh!(concurrently:)
    AdditionalCodeTypeMeasureType.refresh!(concurrently:)
    AdditionalCodeTypeDescription.refresh!(concurrently:)
    AdditionalCodeDescription.refresh!(concurrently:)
    AdditionalCodeDescriptionPeriod.refresh!(concurrently:)
  end
end
