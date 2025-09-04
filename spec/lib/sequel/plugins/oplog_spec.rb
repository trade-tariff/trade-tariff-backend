# rubocop:disable Style/ConstantDefinitionInBlock
# rubocop:disable Style/BeforeAfterAll
# rubocop:disable Style/LeakyConstantDeclaration

RSpec.describe Sequel::Plugins::Oplog do
  before(:all) do
    DB = Sequel::Model.db

    DB.drop_table?(:test_records_oplog, cascade: true)
    DB.drop_table?(:test_records, cascade: true)
    DB.drop_table?(:composite_test_records_oplog, cascade: true)
    DB.drop_table?(:composite_test_records, cascade: true)

    DB.create_table!(:test_records) do
      primary_key :id
      String :name
      String :description
      DateTime :created_at
      DateTime :updated_at
      Integer :oid
    end

    DB.create_table!(:test_records_oplog) do
      primary_key :oid
      Integer :id
      String :name
      String :description
      DateTime :created_at
      DateTime :updated_at
      String :operation
      DateTime :operation_date
    end

    DB.create_table!(:composite_test_records) do
      Integer :part_a
      Integer :part_b
      String :data
      Integer :oid
      primary_key %i[part_a part_b]
    end

    DB.create_table!(:composite_test_records_oplog) do
      primary_key :oid
      Integer :part_a
      Integer :part_b
      String :data
      String :operation
      DateTime :operation_date
    end

    class TestRecord < Sequel::Model(DB[:test_records])
      plugin :oplog, primary_key: :id
      unrestrict_primary_key
    end

    class CompositeTestRecord < Sequel::Model(DB[:composite_test_records])
      plugin :oplog, primary_key: %i[part_a part_b]
      unrestrict_primary_key
    end
  end

  before do
    DB[:test_records_oplog].truncate(restart: true, cascade: true)
    DB[:test_records].truncate(restart: true, cascade: true)
    DB[:composite_test_records_oplog].truncate(restart: true, cascade: true)
    DB[:composite_test_records].truncate(restart: true, cascade: true)
  end

  describe '#previous_record' do
    context 'when there are multiple operation records for the same entity' do
      before do
        # Create operation records directly for testing
        TestRecord::Operation.insert(
          id: 1,
          name: 'First Record',
          description: 'Initial version',
          operation: 'C',
          operation_date: Time.zone.now - 2.days,
        )

        TestRecord::Operation.insert(
          id: 1,
          name: 'First Record Updated',
          description: 'Updated version',
          operation: 'U',
          operation_date: Time.zone.now - 1.day,
        )

        TestRecord::Operation.insert(
          id: 1,
          name: 'First Record Final',
          description: 'Final version',
          operation: 'U',
          operation_date: Time.zone.now,
        )

        TestRecord::Operation.insert(
          id: 2,
          name: 'Second Record',
          description: 'Different record',
          operation: 'C',
          operation_date: Time.zone.now,
        )
      end

      it 'returns the previous operation record for the same entity' do
        latest_operation = TestRecord::Operation.where(id: 1).order(Sequel.desc(:oid)).first
        test_record = TestRecord.new(id: 1, oid: latest_operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record).not_to be_nil
        expect(previous_record.id).to eq(1)
        expect(previous_record.name).to eq('First Record Updated')
        expect(previous_record.oid).to be < latest_operation.oid
      end

      it 'returns records ordered by oid in descending order' do
        latest_operation = TestRecord::Operation.where(id: 1).order(Sequel.desc(:oid)).first
        test_record = TestRecord.new(id: 1, oid: latest_operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record.oid).to be < latest_operation.oid

        if previous_record
          second_test_record = TestRecord.new(id: 1, oid: previous_record.oid)
          second_previous = second_test_record.previous_record
          if second_previous
            expect(second_previous.oid).to be < previous_record.oid
          end
        end
      end
    end

    context 'when there is only one operation record for an entity' do
      before do
        TestRecord::Operation.insert(
          id: 1,
          name: 'Single Record',
          description: 'Only record',
          operation: 'C',
          operation_date: Time.zone.now,
        )
      end

      it 'returns nil when there is no previous record' do
        operation = TestRecord::Operation.where(id: 1).first
        test_record = TestRecord.new(id: 1, oid: operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record).to be_nil
      end
    end

    context 'when filtering by primary keys other than oid' do
      before do
        3.times do |i|
          TestRecord::Operation.insert(
            id: 1,
            name: "Version #{i + 1}",
            description: "Description #{i + 1}",
            operation: 'U',
            operation_date: Time.zone.now - (i * 1.day),
          )
        end
      end

      it 'correctly filters by all primary keys except oid' do
        latest_operation = TestRecord::Operation.where(id: 1).order(Sequel.desc(:oid)).first
        test_record = TestRecord.new(id: 1, oid: latest_operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record).not_to be_nil
        expect(previous_record.id).to eq(1)
        expect(previous_record.oid).to be < latest_operation.oid
      end
    end

    context 'with composite primary keys' do
      it 'handles composite primary keys correctly' do
        CompositeTestRecord::Operation.insert(part_a: 1, part_b: 2, data: 'First', operation: 'C')
        CompositeTestRecord::Operation.insert(part_a: 1, part_b: 2, data: 'Second', operation: 'U')
        CompositeTestRecord::Operation.insert(part_a: 1, part_b: 3, data: 'Different', operation: 'C')

        latest_operation = CompositeTestRecord::Operation.where(part_a: 1, part_b: 2).order(Sequel.desc(:oid)).first
        test_record = CompositeTestRecord.new(part_a: 1, part_b: 2, oid: latest_operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record).not_to be_nil
        expect(previous_record.part_a).to eq(1)
        expect(previous_record.part_b).to eq(2)
        expect(previous_record.data).to eq('First')
        expect(previous_record.oid).to be < latest_operation.oid
      end

      it 'does not return records with different composite key values' do
        CompositeTestRecord::Operation.insert(part_a: 1, part_b: 2, data: 'Target', operation: 'C')
        CompositeTestRecord::Operation.insert(part_a: 1, part_b: 3, data: 'Different', operation: 'C')

        operation = CompositeTestRecord::Operation.where(part_a: 1, part_b: 2).first
        test_record = CompositeTestRecord.new(part_a: 1, part_b: 2, oid: operation.oid)

        previous_record = test_record.previous_record

        expect(previous_record).to be_nil
      end
    end
  end
end

# rubocop:enable Style/ConstantDefinitionInBlock
# rubocop:enable Style/BeforeAfterAll
# rubocop:enable Style/LeakyConstantDeclaration
