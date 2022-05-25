RSpec.shared_examples_for 'an entity mapper missing destroy operation' do |model, filter|
  let(:has_hard_deletes) { false }
  let(:model_primary_keys) { Array.wrap(model.primary_key) }
  let(:change_oplog_deletion_count) { change { model::Operation.where(filter.merge(operation: 'D')).count } }
  let(:change_view_count) { change { model.where(filter).count } }

  it "hides the missing xml nodes from the #{model} view" do
    expect { entity_mapper.import }.to change_view_count.by(-1)
  end

  it "inserts the missing xml nodes as a soft deleted row in the #{model} oplog" do
    expect { entity_mapper.import }.to change_oplog_deletion_count.by(1)
  end

  # TODO: Remove me once all is merged and tested
  context 'when the handle_soft_deletes feature flag is disabled' do
    before do
      allow(TradeTariffBackend).to receive(:handle_soft_deletes?).and_return(false)
    end

    # rubocop:disable RSpec/MultipleExpectations
    it "does not hide the missing xml nodes from the #{model} view" do
      if has_hard_deletes
        expect { entity_mapper.import }.to change_view_count.by(-1)
      else
        expect { entity_mapper.import }.not_to change_view_count
      end
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "does not insert the missing xml nodes as a soft deleted row in the #{model} oplog" do
      expect { entity_mapper.import }.not_to change_oplog_deletion_count
    end
  end
end
