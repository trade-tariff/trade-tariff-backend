module MaterializeViewHelper
  # Materialized views that the commodity query plan seq-scans via Hash Left Join.
  # Calling `.count` on each model forces PostgreSQL to read every page into
  # shared_buffers so the data is warm before PrewarmCommoditiesWorker fires
  # concurrent HTTP requests that would otherwise all pay the cold-read cost.
  VIEWS_TO_PREWARM = %w[
    AdditionalCode
    AdditionalCodeDescription
    BaseRegulation
    Footnote
    FootnoteDescription
    GeographicalArea
    GeographicalAreaDescription
    GeographicalAreaMembership
    Measure
    MeasureComponent
    MeasureCondition
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
