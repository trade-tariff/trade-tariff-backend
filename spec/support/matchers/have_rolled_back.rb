RSpec::Matchers.define :have_rolled_back do |update|
  MaterializeViewHelper.refresh_materialized_view
  match do |_actual|
    corresponding_measures = if update.is_a?(TariffSynchronizer::TaricUpdate)
                               # TARIC does not stamp filename on oplog rows; match by operation_date.
                               Measure.where(operation_date: update.issue_date)
                             else
                               Measure.where(filename: update.filename)
                             end

    corresponding_measures.none? && update.reload
  rescue Sequel::NoExistingObject
    true
  end
end
