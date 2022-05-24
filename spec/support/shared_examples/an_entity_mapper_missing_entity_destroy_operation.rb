RSpec.shared_examples_for 'an entity mapper missing destroy operation' do |relation, model_primary_keys, filter|
  let(:change_oplog_deletion_count) do
    change { relation::Operation.where(filter.merge(operation: 'D')).count }
  end
  it "hides the missing xml nodes from the #{relation} view" do
    before_import_primary_keys = relation.where(filter).pluck(*model_primary_keys)

    entity_mapper.import

    after_import_primary_keys = relation.where(filter).pluck(*model_primary_keys)

    expect(after_import_primary_keys).not_to include(before_import_primary_keys)
  end

  it "inserts the missing xml nodes as a soft deleted row in the #{relation} oplog" do
    expect { entity_mapper.import }.to change_oplog_deletion_count.by(1)
  end

  # TODO: Remove me once all is merged and tested
  context 'when the handle_soft_deletes feature flag is disabled' do
    before do
      allow(TradeTariffBackend).to receive(:handle_soft_deletes?).and_return(false)
    end

    it "does not hide the missing xml nodes from the #{relation} view" do
      before_import_primary_keys = relation.where(filter).pluck(*model_primary_keys)

      entity_mapper.import

      after_import_primary_keys = relation.where(filter).pluck(*model_primary_keys)

      expect(after_import_primary_keys).to include(*before_import_primary_keys)
    end

    it "does not insert the missing xml nodes as a soft deleted row in the #{relation} oplog" do
      expect { entity_mapper.import }.not_to change_oplog_deletion_count
    end
  end
end
