RSpec.describe ChangesTablePopulator::MeasureCreatedOrUpdated do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when the database is empty' do
      before do
        db[:measures_oplog].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end
  end
end
