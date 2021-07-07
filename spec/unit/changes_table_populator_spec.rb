require 'rails_helper'

describe ChangesTablePopulator do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end
  end

  describe '#populate_backlog' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate_backlog }.not_to change(Change, :count)
      end
    end
  end

  describe '#cleanup_outdated' do
    context 'with an empty database' do
      before do
        db[:measures].delete
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t change the changes' do
        expect { described_class.cleanup_outdated }.not_to change(Change, :count)
      end
    end
  end
end
