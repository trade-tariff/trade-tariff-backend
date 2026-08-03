# frozen_string_literal: true

RSpec.describe TaricImporter::EntityMapper do
  subject(:mapper) do
    described_class.new(
      record_hash,
      issue_date: Date.new(2013, 8, 2),
      national_sid_counter:,
    )
  end

  let(:national_sid_counter) { TaricImporter::NationalSidCounter.new }

  let(:record_hash) do
    {
      'transaction_id' => '13924773',
      'record_code' => '430',
      'subrecord_code' => '00',
      'record_sequence_number' => '73',
      'update_type' => update_type,
      'measure' => {
        'measure_sid' => '3318239',
        'measure_type' => '475',
        'geographical_area' => 'US',
        'goods_nomenclature_item_id' => '1202410000',
        'validity_start_date' => '2013-08-01',
        'measure_generating_regulation_role' => '1',
        'measure_generating_regulation_id' => 'D0800470',
        'stopped_flag' => '0',
        'geographical_area_sid' => '103',
        'goods_nomenclature_sid' => '94673',
      },
    }
  end

  let(:update_type) { '3' }

  let(:entity) do
    mapped_entity = nil
    mapper.build { |result| mapped_entity = result }
    mapped_entity
  end

  before do
    Measure.unrestrict_primary_key
  end

  it 'maps the TARIC record to a Measure', :aggregate_failures do
    expect(entity.instance).to be_a(Measure)
    expect(entity.key).to eq('measure')
    expect(entity.element_id).to eq('13924773:73')
    expect(entity.mapper.entity_class).to eq('Measure')
  end

  it 'applies Measure attribute mutations', :aggregate_failures do
    expect(entity.instance.measure_sid.to_s).to eq('3318239')
    expect(entity.instance.measure_type_id).to eq('475')
    expect(entity.instance.geographical_area_id).to eq('US')
    expect(entity.instance.goods_nomenclature_item_id).to eq('1202410000')
  end

  it 'adds oplog attributes', :aggregate_failures do
    expect(entity.instance.operation).to eq(:create)
    expect(entity.instance.operation_date).to eq(Date.new(2013, 8, 2))
  end

  it 'does not persist while mapping' do
    expect { mapper.build }.not_to change(Measure::Operation, :count)
  end

  context 'with an update operation' do
    let(:update_type) { '1' }

    it 'maps it to update' do
      expect(entity.instance.operation).to eq(:update)
    end
  end

  context 'with a destroy operation' do
    let(:update_type) { '2' }

    it 'maps it to destroy' do
      expect(entity.instance.operation).to eq(:destroy)
    end
  end

  context 'with an unknown operation' do
    let(:update_type) { '9' }

    it 'raises an error' do
      expect { mapper.build }
        .to raise_error(TaricImporter::UnknownOperationError)
    end

    it 'carries the taric source, a descriptive message and the failing record as context', :aggregate_failures do
      expect { mapper.build }.to raise_error(TaricImporter::UnknownOperationError) do |caught|
        expect(caught.source).to eq(:taric)
        expect(caught.message).to eq('Unknown TARIC operation: 9')
        expect(caught.context).to eq(transaction: record_hash)
        expect(caught.original).to be_nil
      end
    end
  end

  context 'when the transaction id is missing' do
    let(:record_hash) do
      {
        'record_code' => '430',
        'subrecord_code' => '00',
        'record_sequence_number' => '73',
        'update_type' => '3',
        'measure' => {
          'measure_sid' => '3318239',
        },
      }
    end

    it 'raises an error' do
      expect { mapper.build }
        .to raise_error(ArgumentError, 'TARIC transaction does not have required attributes')
    end
  end

  context 'when the primary key is missing' do
    let(:record_hash) do
      {
        'transaction_id' => '13924773',
        'record_code' => '430',
        'subrecord_code' => '00',
        'record_sequence_number' => '73',
        'update_type' => '3',
        'measure' => {
          'measure_type' => '475',
          'geographical_area' => 'US',
          'goods_nomenclature_item_id' => '1202410000',
        },
      }
    end

    it 'raises an error' do
      expect { mapper.build }
        .to raise_error(ArgumentError, 'TARIC create for Measure missing primary key: measure_sid')
    end
  end

  context 'when creating a national MeasureCondition with no sid in the source data' do
    let(:record_hash) do
      {
        'transaction_id' => '13924774',
        'record_code' => '350',
        'subrecord_code' => '00',
        'record_sequence_number' => '74',
        'update_type' => '3',
        'measure_condition' => {
          'measure_sid' => '3318239',
          'condition_code' => 'B',
          'component_sequence_number' => '1',
          'action_code' => '01',
        },
      }
    end

    before { MeasureCondition.unrestrict_primary_key }

    it 'assigns a national (negative) sid, since writes no longer go through a before_create hook' do
      expect(entity.instance.measure_condition_sid).to be_present
      expect(entity.instance.measure_condition_sid).to be < 0
    end
  end

  context 'when two national MeasureConditions are mapped in the same import before either is persisted' do
    let(:record_hash_for) do
      lambda do |transaction_id, record_sequence_number|
        {
          'transaction_id' => transaction_id,
          'record_code' => '350',
          'subrecord_code' => '00',
          'record_sequence_number' => record_sequence_number,
          'update_type' => '3',
          'measure_condition' => {
            'measure_sid' => '3318239',
            'condition_code' => 'B',
            'component_sequence_number' => '1',
            'action_code' => '01',
          },
        }
      end
    end

    before { MeasureCondition.unrestrict_primary_key }

    it 'assigns each a distinct negative sid instead of colliding' do
      first_mapper = described_class.new(record_hash_for.call('13924774', '74'), issue_date: Date.new(2013, 8, 2), national_sid_counter:)
      second_mapper = described_class.new(record_hash_for.call('13924775', '75'), issue_date: Date.new(2013, 8, 2), national_sid_counter:)

      first_entity = nil
      second_entity = nil
      first_mapper.build { |result| first_entity = result }
      second_mapper.build { |result| second_entity = result }

      expect(first_entity.instance.measure_condition_sid).not_to eq(second_entity.instance.measure_condition_sid)
    end
  end

  context 'when creating a MeasureCondition that already has a sid in the source data' do
    let(:record_hash) do
      {
        'transaction_id' => '13924775',
        'record_code' => '350',
        'subrecord_code' => '00',
        'record_sequence_number' => '75',
        'update_type' => '3',
        'measure_condition' => {
          'measure_condition_sid' => '555',
          'measure_sid' => '3318239',
          'condition_code' => 'B',
          'component_sequence_number' => '1',
          'action_code' => '01',
        },
      }
    end

    before { MeasureCondition.unrestrict_primary_key }

    it 'keeps the sid from the source data unchanged' do
      expect(entity.instance.measure_condition_sid.to_s).to eq('555')
    end
  end
end
