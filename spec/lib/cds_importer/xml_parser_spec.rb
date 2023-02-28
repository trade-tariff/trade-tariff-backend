RSpec.describe CdsImporter::XmlParser::Reader do
  describe '#characters' do
    shared_examples 'a characters callback' do |in_target, val, expected_result|
      subject(:reader) { described_class.new(xml_io, handler) }

      let(:xml_io) { StringIO.new }
      let(:stack) { [{__content__: ''}] }
      let(:handler) { OpenStruct.new { def process_xml_node(_key, _attributes); end } }

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
end
