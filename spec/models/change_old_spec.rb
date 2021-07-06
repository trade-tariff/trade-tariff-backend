require 'rails_helper'

describe ChangeOld do
  let!(:measure) { create :measure }
  let(:change_old)   do
    described_class.new(
      model: 'Measure',
      oid: measure.source.oid,
      operation_date: measure.source.operation_date,
      operation: measure.operation,
    )
  end

  describe '#operation_record' do
    it 'returns relevant models operation record' do
      expect(change_old.operation_record).to eq measure.source
    end
  end

  describe '#record' do
    it 'returns model associated with change operation' do
      expect(change_old.record.pk).to eq measure.pk
    end
  end
end
