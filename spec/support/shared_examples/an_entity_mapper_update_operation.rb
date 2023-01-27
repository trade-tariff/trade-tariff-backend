RSpec.shared_examples_for 'an entity mapper update operation' do |relation|
  it "changes the count of #{relation} with an update operation" do
    expect { entity_mapper.import }.to change { relation::Operation.where(operation: 'U').count }.by(1)
  end
end
