RSpec.shared_examples_for 'an entity mapper destroy operation' do |relation|
  it "inserts a soft delete record for #{relation}" do
    expect { entity_mapper.import }.to change { relation::Operation.where(operation: 'D').count }.by(1)
  end

  it "causes the #{relation} record to no longer be visible in the view" do
    expect { entity_mapper.import }.to change { relation.count }.by(-1)
  end
end
