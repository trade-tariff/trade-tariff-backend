RSpec.shared_examples_for 'an entity mapper' do |expected_entity_class, expected_mapping_root|
  describe '.entity_class' do
    subject(:entity_class) { described_class.entity_class }

    it { is_expected.to eq(expected_entity_class) }
  end

  describe '.mapping_root' do
    subject(:mapping_root) { described_class.mapping_root }

    it { is_expected.to eq(expected_mapping_root) }
  end

  describe '#parse' do
    subject(:parsed) { described_class.new(xml_node).parse.first }

    it { expect(parsed[:instance].values).to eq(expected_values) }
    it { expect(parsed[:instance]).to be_a(expected_entity_class.constantize) }
    it { expect(parsed[:expanded_attributes]).to be_a(Hash) }
  end
end
