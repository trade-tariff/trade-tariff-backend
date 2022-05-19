RSpec.shared_examples_for 'an entity mapper create operation' do |relation|
  it { expect { entity_mapper.import }.to change { relation::Operation.where(operation: 'C').count }.by(1) }
end
