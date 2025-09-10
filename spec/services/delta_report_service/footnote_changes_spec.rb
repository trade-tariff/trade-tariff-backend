RSpec.describe DeltaReportService::FootnoteChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:footnote) { create(:footnote, :with_description, oid: '999') }
  let(:instance) { described_class.new(footnote, date) }

  before do
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:footnote1) { build(:footnote, oid: 1, operation_date: date) }
    let(:footnote2) { build(:footnote, oid: 2, operation_date: date) }
    let(:footnotes) { [footnote1, footnote2] }

    before do
      allow(Footnote).to receive_message_chain(:where, :order).and_return(footnotes)
    end

    it 'finds footnotes for the given date and returns analyzed changes' do
      instance1 = described_class.new(footnote1, date)
      instance2 = described_class.new(footnote2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'Footnote' })
      allow(instance2).to receive(:analyze).and_return({ type: 'Footnote' })

      result = described_class.collect(date)

      expect(Footnote).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'Footnote' }, { type: 'Footnote' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Footnote')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Footnote updated',
        change: nil,
      )
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'Footnote',
          footnote_oid: footnote.oid,
          date_of_effect: date,
          description: 'Footnote updated',
          change: "#{footnote.code}: #{footnote.description}",
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('description updated') }

      it 'uses the change value with the footnote code' do
        result = instance.analyze
        expect(result[:change]).to eq("#{footnote.code}: description updated")
      end
    end
  end
end
