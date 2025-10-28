RSpec.describe DeltaReportService::CertificateChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:certificate) do
    create(:certificate, :with_description, certificate_type_code: 'Y', certificate_code: '999')
  end
  let(:instance) { described_class.new(certificate, date) }

  before do
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:certificate1) { build(:certificate, oid: 1, operation_date: date) }
    let(:certificate2) { build(:certificate, oid: 2, operation_date: date) }
    let(:certificates) { [certificate1, certificate2] }

    before do
      allow(Certificate).to receive_message_chain(:where, :where, :map, :compact).and_return([{ type: 'Certificate' }, { type: 'Certificate' }])
    end

    it 'finds certificates for the given date and returns analyzed changes' do
      result = described_class.collect(date)

      expect(Certificate).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'Certificate' }, { type: 'Certificate' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Certificate')
    end
  end

  describe '#excluded_columns' do
    it 'includes measure-specific excluded columns' do
      expected = instance.send(:excluded_columns)
      expect(expected).to include(:national)
    end

    it 'includes base excluded columns' do
      base_excluded = %i[oid operation operation_date created_at updated_at filename]
      expected = instance.send(:excluded_columns)

      base_excluded.each do |column|
        expect(expected).to include(column)
      end
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Certificate updated',
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
          type: 'Certificate',
          certificate_type_code: 'Y',
          certificate_code: '999',
          date_of_effect: date,
          description: 'Certificate updated',
          change: 'Y999',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('description updated') }

      it 'uses the change value instead of certificate id' do
        result = instance.analyze
        expect(result[:change]).to eq('description updated')
      end
    end
  end
end
