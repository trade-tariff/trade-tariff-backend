RSpec.shared_examples_for 'an entity mapper missing destroy operation' do |relation, model_primary_key, filter|
  it 'removes the secondary entities that are not present in the xml node from the view' do
    before_period_sids = relation.where(filter).pluck(model_primary_key)

    entity_mapper.import

    actual_period_sids = relation.where(filter).pluck(model_primary_key)

    expect(actual_period_sids).not_to include(before_period_sids)
  end

  it 'soft deletes the missing secondary entities' do
    before_period_sids = relation.where(filter).pluck(model_primary_key)

    entity_mapper.import

    soft_deleted_sids = relation::Operation.where(filter.merge(operation: 'D')).pluck(:footnote_description_period_sid)

    expect(before_period_sids).to eq(soft_deleted_sids)
  end

  # TODO: Remove me once all is merged and tested
  context 'when the handle_soft_deletes feature flag is disabled' do
    before do
      allow(TradeTariffBackend).to receive(:handle_soft_deletes?).and_return(false)
    end

    it 'does not remove the secondary entities that are not present in the xml node from the view' do
      before_period_sids = relation.where(filter).pluck(model_primary_key)

      entity_mapper.import

      actual_period_sids = relation.where(filter).pluck(model_primary_key)

      expect(actual_period_sids).to include(*before_period_sids)
    end
  end
end
