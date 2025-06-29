RSpec.describe TaricImporter::RecordProcessor::Record do
  let(:record_hash) do
    { 'transaction_id' => '31946',
      'record_code' => '130',
      'subrecord_code' => '05',
      'record_sequence_number' => '1',
      'update_type' => '3',
      'language_description' =>
      { 'language_code_id' => 'FR',
        'language_id' => 'EN',
        'description' => 'French' } }
  end

  describe 'initialization' do
    subject(:record) { described_class.new(record_hash) }

    it 'assigns transaction id' do
      expect(record.transaction_id).to eq '31946'
    end

    it 'assigns model class' do
      expect(record.klass).to eq LanguageDescription
    end

    it 'assigns primary key as string array' do
      expect(record.primary_key).to eq Array(LanguageDescription.primary_key).map(&:to_s)
    end

    it 'assigns sanitized attributes' do
      expect(record.attributes).to eq({ 'language_code_id' => 'FR', 'language_id' => 'EN', 'description' => 'French', 'filename' => nil })
    end
  end

  describe '#attributes=' do
    subject(:record) { described_class.new(record_hash) }

    context 'when not ovverriding mutations' do
      it 'assigns attributes unmutated' do
        record.attributes = { 'foo' => 'bar' }

        expect(record.attributes).to eq({ 'language_code_id' => nil, 'language_id' => nil, 'description' => nil, 'foo' => 'bar', 'filename' => nil })
      end
    end

    context 'when ovverriding mutated attributes' do
      before do
        ovverriding_mutator_class = Class.new do
          def self.mutate(attributes)
            attributes['foo_id'] = attributes.delete('foo')
            attributes
          end
        end

        stub_const(
          'TaricImporter::RecordProcessor::AttributeMutatorOverrides::LanguageDescriptionAttributeMutator',
          ovverriding_mutator_class,
        )
      end

      it 'assigns mutated attributes' do
        record.attributes = { 'foo' => 'bar' }

        expect(record.attributes).to eq({ 'language_code_id' => nil, 'language_id' => nil, 'description' => nil, 'foo_id' => 'bar', 'filename' => nil })
      end
    end
  end
end
