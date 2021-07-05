require 'rails_helper'

describe DeltaTablesGenerator do
  let(:db) { Sequel::Model.db }

  describe '#generate' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract deltas' do
        expect { described_class.generate }.not_to change(Delta, :count)
      end
    end
  end

  describe '#generate_backlog' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract deltas' do
        expect { described_class.generate_backlog }.not_to change(Delta, :count)
      end
    end
  end

  describe '#cleanup_outdated' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t change the deltas' do
        expect { described_class.cleanup_outdated }.not_to change(Delta, :count)
      end
    end
  end
end
