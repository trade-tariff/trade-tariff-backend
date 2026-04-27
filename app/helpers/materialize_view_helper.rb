module MaterializeViewHelper
  def refresh_materialized_view(concurrently: false)
    eager_load_materialized_view_models

    Sequel::Plugins::Oplog.models.each do |model|
      if model.materialized? && model.actually_materialized?
        model.refresh!(concurrently:)
      end
    end

    GoodsNomenclatures::TreeNode.refresh!(concurrently:)
  end

  def eager_load_materialized_view_models
    return if Rails.application.config.x.materialized_view_models_loaded

    Rails.application.eager_load!
    Rails.application.config.x.materialized_view_models_loaded = true
  end

  module_function :refresh_materialized_view
  module_function :eager_load_materialized_view_models
end
