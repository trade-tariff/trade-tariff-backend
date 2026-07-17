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
end
