RSpec.describe GoodsNomenclatureChangeAccumulator do
  before { described_class.reset! }

  after { described_class.reset! }

  describe '.push!' do
    it 'accumulates a change' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      expect(described_class.pending_count).to eq(1)
    end

    it 'accumulates multiple changes' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.push!(sid: 2, change_type: :structure_changed, item_id: '0102040000')
      expect(described_class.pending_count).to eq(2)
    end

    it 'raises on unknown change type' do
      expect {
        described_class.push!(sid: 1, change_type: :bogus, item_id: '0102030000')
      }.to raise_error(ArgumentError, /Unknown change type/)
    end

    it 'accepts all valid change types' do
      described_class::CHANGE_TYPES.each_with_index do |type, i|
        described_class.push!(sid: i, change_type: type, item_id: '0102030000')
      end
      expect(described_class.pending_count).to eq(3)
    end
  end

  describe '.flush!' do
    before { allow(GoodsNomenclatureChangeWorker).to receive(:perform_async) }

    it 'enqueues one worker per chapter' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.push!(sid: 2, change_type: :structure_changed, item_id: '0201040000')

      described_class.flush!

      expect(GoodsNomenclatureChangeWorker).to have_received(:perform_async).twice
    end

    it 'groups changes from the same chapter into one worker call' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.push!(sid: 2, change_type: :structure_changed, item_id: '0102040000')

      described_class.flush!

      expect(GoodsNomenclatureChangeWorker).to have_received(:perform_async).with(
        '01',
        { '1' => [:moved], '2' => [:structure_changed] },
      ).once
    end

    it 'deduplicates change types per SID' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.push!(sid: 1, change_type: :description_changed, item_id: '0102030000')

      described_class.flush!

      expect(GoodsNomenclatureChangeWorker).to have_received(:perform_async).with(
        '01',
        { '1' => %i[moved description_changed] },
      ).once
    end

    it 'clears the accumulator after flush' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.flush!
      expect(described_class.pending_count).to eq(0)
    end

    it 'does nothing when empty' do
      described_class.flush!
      expect(GoodsNomenclatureChangeWorker).not_to have_received(:perform_async)
    end
  end

  describe '.reset!' do
    it 'clears all pending changes' do
      described_class.push!(sid: 1, change_type: :moved, item_id: '0102030000')
      described_class.reset!
      expect(described_class.pending_count).to eq(0)
    end
  end

  describe 'Change' do
    subject(:change) { described_class::Change.new(sid: 1, change_type: :moved, item_id: '0102030000') }

    it 'extracts chapter code from item_id' do
      expect(change.chapter_code).to eq('01')
    end
  end
end
