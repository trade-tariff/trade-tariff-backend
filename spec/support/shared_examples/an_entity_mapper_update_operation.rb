RSpec.shared_examples_for 'an entity mapper update operation' do |relation|
  it "changes the count of #{relation} with an update operation" do
    yielded_objects = []

    entity_mapper.build do |entity|
      yielded_objects << entity
    end

    expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
      .to include(
        { relation.name.to_sym => hash_including(operation: 'U') },
      )
  end
end
