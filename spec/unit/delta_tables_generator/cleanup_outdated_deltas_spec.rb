require 'rails_helper'

describe DeltaTablesGenerator::CleanupOutdatedDeltas do
  let(:db) { Sequel::Model.db }

  describe '#run' do
    context 'when the database is empty' do
      before do
        db[:deltas].delete
      end

      it 'doesn\'t remove deltas' do
        expect { described_class.run }.not_to change(Delta, :count)
      end
    end

    context 'when there are deltas but they\'re not outdated' do
      before do
        create :delta
        create :delta_measure
      end

      it 'doesn\'t remove deltas' do
        expect { described_class.run }.not_to change(Delta, :count)
      end
    end

    context 'when there are outdated deltas' do
      before do
        create :delta
        create :delta, delta_date: Date.current.ago(4.months)
        create :delta_measure
      end

      it 'remove the outdated delta' do
        expect { described_class.run }.to change(Delta, :count).by(-1)
      end
    end
  end
end
