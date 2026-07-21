# frozen_string_literal: true

RSpec.describe TaricImporter::EntityMapper do
  subject(:mapper) do
    described_class.new(
      record_hash,
      issue_date: Date.new(2013, 8, 2),
    )
  end

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
