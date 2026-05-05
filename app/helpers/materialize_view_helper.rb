module MaterializeViewHelper
  # Tables the commodity query plan always seq-scans via Hash Left Join.
  # Loading them into shared_buffers here means they are warm before
  # PrewarmCommoditiesWorker fires HTTP requests that hit them concurrently.
  VIEWS_TO_PREWARM = %w[
    BaseRegulation
    ModificationRegulation
  ].freeze

  # Small reference tables that almost never change between daily syncs.
  # Each uses plugin :static_cache (skipped in test env) so that Model.all
  # and Model[pk] are served from process memory without a DB round-trip.
  # After each materialized-view refresh we call load_cache to keep the
  # in-memory copies current.
  STATIC_CACHE_MODEL_NAMES = %w[
    DutyExpression
    DutyExpressionDescription
    MeasureAction
    MeasureActionDescription
    MeasureConditionCode
    MeasureConditionCodeDescription
    MeasureType
    MeasureTypeDescription
    MeasureTypeSeriesDescription
    MeasurementUnit
    MeasurementUnitAbbreviation
    MeasurementUnitDescription
    MeasurementUnitQualifier
    MeasurementUnitQualifierDescription
    MonetaryUnit
  ].freeze

  def refresh_materialized_view
    eager_load_materialized_view_models

    Sequel::Plugins::Oplog.models.each do |model|
      model.refresh! if model.materialized? && model.actually_materialized?
    end

    GoodsNomenclatures::TreeNode.refresh!

    reload_static_caches
    prewarm_views
  end

  def eager_load_materialized_view_models
    return if Rails.application.config.x.materialized_view_models_loaded

    Rails.application.eager_load!
    Rails.application.config.x.materialized_view_models_loaded = true
  end

  # Repopulate the in-memory static caches after the daily MV refresh so
  # reference data stays current without an app restart.  Skipped in test
  # because the models do not load plugin :static_cache in that environment.
  def reload_static_caches
    return if Rails.env.test?

    STATIC_CACHE_MODEL_NAMES.each { |name| name.constantize.load_cache }
  end

  def prewarm_views
    VIEWS_TO_PREWARM.each do |model_name|
      model_name.constantize.count
    end
  end

  module_function :refresh_materialized_view
  module_function :eager_load_materialized_view_models
  module_function :reload_static_caches
  module_function :prewarm_views
end
