RSpec.describe Change do
  let(:db) { Sequel::Model.db }

  describe '#cleanup' do
    context 'when the database is empty' do
      before do
        db[:changes].delete
      end

      it 'doesn\'t remove changes' do
        expect { described_class.cleanup }.not_to change(described_class, :count)
      end
    end

    context 'when there are changes but they\'re not outdated' do
      before do
        create :change
        create :change_measure
      end

      it 'doesn\'t remove changes' do
        expect { described_class.cleanup }.not_to change(described_class, :count)
      end
    end

    context 'when there are outdated changes' do
      before do
        create :change
        create :change, change_date: 4.months.ago.beginning_of_day
        create :change_measure
      end

      it 'remove the outdated change' do
        expect { described_class.cleanup }.to change(described_class, :count).by(-1)
      end
    end
  end
end
