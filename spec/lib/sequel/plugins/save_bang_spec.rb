RSpec.describe Sequel::Plugins::SaveBang do
  before do
    db = Sequel::Model.db
    db.drop_table?(:save_bang_records, cascade: true)
    db.create_table!(:save_bang_records) do
      primary_key :id
      String :name
    end

    model = Class.new(Sequel::Model(:save_bang_records)) do
      plugin :validation_helpers

      self.raise_on_save_failure = false

      def validate
        super
        validates_presence :name
      end
    end

    stub_const('SaveBangRecord', model)
  end

  describe '.create!' do
    it 'persists a valid record' do
      record = SaveBangRecord.create!(name: 'linen')

      expect(record.id).not_to be_nil
      expect(SaveBangRecord.first.name).to eq('linen')
    end

    context 'when the record is invalid' do
      it 'raises validation failed' do
        expect { SaveBangRecord.create!(name: nil) }.to raise_error(Sequel::ValidationFailed)
        expect(SaveBangRecord.count).to eq(0)
      end
    end
  end

  describe '#save!' do
    it 'persists changes to an existing record' do
      record = SaveBangRecord.create!(name: 'linen')
      record.name = 'cotton'

      expect(record.save!).to eq(record)
      expect(record.reload.name).to eq('cotton')
    end

    context 'when raise_on_save_failure is false' do
      it 'raises validation failed' do
        record = SaveBangRecord.new(name: nil)

        expect(record.raise_on_save_failure).to be(false)
        expect(record.save).to be_nil
        expect { record.save! }.to raise_error(Sequel::ValidationFailed)
        expect(SaveBangRecord.count).to eq(0)
      end
    end
  end

  describe '#update!' do
    let(:record) { SaveBangRecord.create!(name: 'linen') }

    it 'persists the new values' do
      expect(record.update!(name: 'cotton')).to eq(record)
      expect(record.reload.name).to eq('cotton')
    end

    context 'when the values are invalid' do
      it 'raises validation failed' do
        expect { record.update!(name: nil) }.to raise_error(Sequel::ValidationFailed)
        expect(record.reload.name).to eq('linen')
      end
    end
  end

  describe '#destroy!' do
    let(:record) { SaveBangRecord.create!(name: 'linen') }

    it 'deletes the record' do
      expect(record.destroy!).to eq(record)
      expect(SaveBangRecord.count).to eq(0)
    end

    context 'when a before destroy hook cancels' do
      before { SaveBangRecord.define_method(:before_destroy) { cancel_action('stopped') } }

      it 'raises hook failed' do
        expect(record.destroy).to be_nil
        expect { record.destroy! }.to raise_error(Sequel::HookFailed, 'stopped')
        expect(SaveBangRecord.count).to eq(1)
      end
    end
  end

  describe 'on a dataset' do
    before do
      SaveBangRecord.create!(name: 'linen')
      SaveBangRecord.create!(name: 'cotton')
    end

    describe '#update!' do
      it 'updates matching rows' do
        expect(SaveBangRecord.where(name: 'linen').update!(name: 'wool')).to eq(1)
        expect(SaveBangRecord.where(name: 'wool').count).to eq(1)
        expect(SaveBangRecord.where(name: 'cotton').count).to eq(1)
      end
    end

    describe '#destroy!' do
      it 'destroys matching rows' do
        expect(SaveBangRecord.where(name: 'linen').destroy!).to eq(1)
        expect(SaveBangRecord.select_map(:name)).to eq(%w[cotton])
      end
    end
  end
end
