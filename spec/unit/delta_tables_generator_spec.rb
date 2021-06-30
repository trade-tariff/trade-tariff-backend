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
end
