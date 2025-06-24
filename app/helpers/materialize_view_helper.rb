module MaterializeViewHelper
  def refresh_materialized_view(concurrently: false)
    GoodsNomenclatures::TreeNode.refresh!(concurrently:)

    Sequel::Plugins::Oplog.models.each do |model|
      if model.materialized?
        model.refresh!(concurrently:)
      end
    end
  end
end
