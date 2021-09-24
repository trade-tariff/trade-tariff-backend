RSpec.describe FullTemporaryStopRegulation do
  let(:fts_regulation) { build :fts_regulation, effective_enddate: Date.current }

  describe '#regulation_id' do
    it 'is an alias for full temporary stop regulation id' do
      expect(fts_regulation.regulation_id).to eq fts_regulation.full_temporary_stop_regulation_id
    end
  end

  describe '#effective_end_date' do
    it 'is an alias for effective_enddate' do
      expect(fts_regulation.effective_end_date).to eq fts_regulation.effective_enddate.to_date
    end
  end

  describe '#effective_start_date' do
    it 'is an alias for validity_start_date' do
      expect(fts_regulation.effective_start_date).to eq fts_regulation.validity_start_date.to_date
    end
  end
end
