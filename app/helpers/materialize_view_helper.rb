module MaterializeViewHelper
  def refresh_materialized_view(concurrently: false)
    Sequel::Plugins::Oplog.models.each do |model|
      if model.materialized?
        model.refresh!(concurrently:)
      end
    end

    GoodsNomenclatures::TreeNode.refresh!(concurrently:)
  end
end
