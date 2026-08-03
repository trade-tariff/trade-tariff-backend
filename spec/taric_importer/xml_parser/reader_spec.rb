RSpec.describe TaricImporter::XmlParser::Reader do
  subject(:reader) { described_class.new(xml_io, 'record', handler) }

  let(:xml_io) { StringIO.new }
  let(:handler) { Class.new { def process_xml_node(_attributes); end }.new }

  describe '#characters' do
    shared_examples 'a characters callback' do |in_target, val, expected_result|
      let(:stack) { [{ __content__: '' }] }

      before do
        reader.instance_variable_set('@in_target', in_target)
        reader.instance_variable_set('@stack', stack)
        reader.instance_variable_set('@node', stack.first)
      end

      it { expect(reader.characters(val)).to eq(expected_result) }
    end

    it_behaves_like 'a characters callback', true, "hello\nfoo", "hello\nfoo"
    it_behaves_like 'a characters callback', true, "\n        ", nil
    it_behaves_like 'a characters callback', true, '', ''
    it_behaves_like 'a characters callback', true, nil, nil
    it_behaves_like 'a characters callback', false, 'foobarbazqux', nil
  end

  describe '#error' do
    it 'raises a TaricImporter::ImportException carrying the parser message', :aggregate_failures do
      expect { reader.error('not well-formed (invalid token)') }
        .to raise_error(TaricImporter::ImportException) do |caught|
          expect(caught.message).to eq('not well-formed (invalid token)')
          expect(caught.original).to be_nil
        end
    end
  end
end
