RSpec.shared_examples_for 'an entity mapper destroy operation' do |relation|
  it "inserts a soft delete record for #{relation}" do
    yielded_objects = []

    entity_mapper.import do |entity|
      yielded_objects << entity
    end

    expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
      .to include(
        { relation.name.to_sym => hash_including(operation: 'D') },
      )
  end
end
