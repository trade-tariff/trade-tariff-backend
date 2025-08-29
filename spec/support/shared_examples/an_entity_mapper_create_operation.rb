RSpec.shared_examples_for 'an entity mapper create operation' do |relation|
  it {
    yielded_objects = []

    entity_mapper.build { |entity| yielded_objects << entity }

    expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
      .to include(
        { relation.name.to_sym => hash_including(operation: 'C') },
      )
  }
end
