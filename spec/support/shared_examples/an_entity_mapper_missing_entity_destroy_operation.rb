RSpec.shared_examples_for 'an entity mapper missing destroy operation' do |relation, model_primary_key, filter|
  it "hides the missing xml nodes from the #{relation} view" do
    before_import_period_sids = relation.where(filter).pluck(model_primary_key)

    entity_mapper.import

    after_import_period_sids = relation.where(filter).pluck(model_primary_key)

    expect(after_import_period_sids).not_to include(before_import_period_sids)
  end

  it "inserts the missing xml nodes as a soft deleted row in the #{relation} oplog" do
    before_import_period_sids = relation.where(filter).pluck(model_primary_key)

    entity_mapper.import

    soft_deleted_sids = relation::Operation.where(filter.merge(operation: 'D')).pluck(:footnote_description_period_sid)

    expect(before_import_period_sids).to eq(soft_deleted_sids)
  end

  # TODO: Remove me once all is merged and tested
  context 'when the handle_soft_deletes feature flag is disabled' do
    before do
      allow(TradeTariffBackend).to receive(:handle_soft_deletes?).and_return(false)
    end

    it "does not hide the missing xml nodes from the #{relation} view" do
      before_import_period_sids = relation.where(filter).pluck(model_primary_key)

      entity_mapper.import

      after_import_period_sids = relation.where(filter).pluck(model_primary_key)

      expect(after_import_period_sids).to include(*before_import_period_sids)
    end

    it "does not insert the missing xml nodes as a soft deleted row in the #{relation} oplog" do
      change_oplog_deletion_count = change { relation::Operation.where(filter.merge(operation: 'D')).count }

      expect { entity_mapper.import }.not_to change_oplog_deletion_count
    end
  end
end
