module MaterializeViewHelper
  # Tables the commodity query plan always seq-scans via Hash Left Join.
  # Loading them into shared_buffers here means they are warm before
  # PrewarmCommoditiesWorker fires HTTP requests that hit them concurrently.
  VIEWS_TO_PREWARM = %w[
    BaseRegulation
    ModificationRegulation
  ].freeze

  def refresh_materialized_view
    eager_load_materialized_view_models

    Sequel::Plugins::Oplog.models.each do |model|
      model.refresh! if model.materialized? && model.actually_materialized?
    end

    GoodsNomenclatures::TreeNode.refresh!

    prewarm_views
  end

  def eager_load_materialized_view_models
    return if Rails.application.config.x.materialized_view_models_loaded

    Rails.application.eager_load!
    Rails.application.config.x.materialized_view_models_loaded = true
  end

  def prewarm_views
    VIEWS_TO_PREWARM.each do |model_name|
      model_name.constantize.count
    end
  end

  module_function :refresh_materialized_view
  module_function :eager_load_materialized_view_models
  module_function :prewarm_views
end
