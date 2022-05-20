RSpec.shared_examples_for 'an entity mapper update operation' do |relation|
  it { expect { entity_mapper.import }.to change { relation::Operation.where(operation: 'U').count }.by(1) }
end
