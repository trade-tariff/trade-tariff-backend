require 'rails_helper'

describe CdsImporter::EntityMapper do
  let(:xml_node) do
    {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'metainfo' => {
        'origin' => 'N',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
      'filename' => 'test.gzip',
    }
  end
  let(:mapper) { described_class.new('AdditionalCode', xml_node) }

  before do
    stub_const('CdsImporter::EntityMapper::ALL_MAPPERS', [CdsImporter::EntityMapper::AdditionalCodeMapper])
  end

  describe '#import' do
    context 'when cds logger enabled' do
      before do
        allow(TariffSynchronizer).to receive(:cds_logger_enabled).and_return(true)
      end

      it 'calls safe method' do
        expect(mapper).to receive(:save_record)
        mapper.import
      end
    end

    context 'when cds logger disabled' do
      it 'calls bang method' do
        expect(mapper).to receive(:save_record!)
        mapper.import
      end

      it 'raises an error and stop import' do
        allow(AdditionalCode::Operation).to receive(:insert).and_raise(StandardError)
        expect { mapper.import }.to raise_error(StandardError)
      end
    end

    it 'calls insert method for operation class' do
      expect(AdditionalCode::Operation).to receive(:insert).with(
        hash_including(additional_code: '169', additional_code_sid: 3084, additional_code_type_id: '8', operation: 'U', filename: 'test.gzip'),
      )
      mapper.import
    end

    it 'saves record for any instance' do
      expect { mapper.import }.to change(AdditionalCode, :count).by(1)
    end

    it 'saves all attributes for record' do
      mapper.import
      record = AdditionalCode.last
      aggregate_failures do
        expect(record.additional_code).to eq '169'
        expect(record.additional_code_sid).to eq 3084
        expect(record.additional_code_type_id).to eq '8'
        expect(record.operation).to eq :update
        expect(record.validity_start_date.to_s).to eq '1991-06-01 00:00:00 UTC'
        expect(record.validity_end_date.to_s).to eq '1996-06-14 23:59:59 UTC'
        expect(record.filename).to eq 'test.gzip'
        expect(record.national).to eq true
      end
    end

    it 'selects mappers by mapping root' do
      expect_any_instance_of(CdsImporter::EntityMapper::AdditionalCodeMapper).to receive(:parse).and_call_original
      mapper.import
    end

    it 'assigns filename' do
      mapper.import
      expect(AdditionalCode.last.filename).to eq 'test.gzip'
    end
  end
end
