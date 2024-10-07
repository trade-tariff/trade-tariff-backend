class MockedModel
  attr_reader :values, :fields

  def set_fields(values, fields)
    @values = values
    @fields = fields

    self
  end

  def self.primary_key
    :bar
  end
end

RSpec.describe CdsImporter::EntityMapper::BaseMapper do
  let(:primary_mocked_mapper) do
    Class.new(described_class) do
      # No mapping path pulls base values for the mapper out of the primary node
      self.entity_class = 'MockedModel'
      self.mapping_root = 'MockedModel'
      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        'flibble' => :squiloogle,
        'foo.bar' => :qux,
        'foo.baz' => :qaz,
      )

      def self.name
        'CdsImporter::EntityMapper::MockedModelMapper'
      end
    end
  end

  let(:secondary_mocked_mapper) do
    Class.new(described_class) do
      self.entity_class = 'MockedModel'
      self.mapping_root = 'Primary'
      self.mapping_path = 'mockedModel'
      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        'flibble' => :squiloogle,
        'mockedModel.foo.bar' => :qux,
        'mockedModel.foo.baz' => :qaz,
      )
      self.exclude_mapping = %w[validityStartDate]

      def self.name
        'CdsImporter::EntityMapper::SecondaryMapper'
      end

      before_oplog_inserts do |xml_node|
        xml_node
      end

      before_building_model do |xml_node|
        xml_node
      end
    end
  end

  shared_examples_for 'an entity mapper accessor' do |accessor|
    it { expect { described_class.public_send("#{accessor}=", 'foo') }.to change(described_class, accessor).from(nil).to('foo') }
  end

  it_behaves_like 'an entity mapper accessor', :entity_class
  it_behaves_like 'an entity mapper accessor', :entity_mapping
  it_behaves_like 'an entity mapper accessor', :mapping_path
  it_behaves_like 'an entity mapper accessor', :mapping_root
  it_behaves_like 'an entity mapper accessor', :exclude_mapping
  it_behaves_like 'an entity mapper accessor', :primary_key_mapping

  describe '.before_oplog_inserts_callbacks' do
    it { expect(secondary_mocked_mapper.before_oplog_inserts_callbacks).to include(an_instance_of(Proc)) }
  end

  describe '.before_building_model_callbacks' do
    it { expect(secondary_mocked_mapper.before_building_model_callbacks).to include(an_instance_of(Proc)) }
  end

  describe '.base_mapping' do
    it 'returns the mapped base mappings without excluded' do
      expect(secondary_mocked_mapper.base_mapping).to eq(
        'mockedModel.metainfo.opType' => :operation,
        'mockedModel.metainfo.origin' => :national,
        'mockedModel.metainfo.transactionDate' => :operation_date,
        'mockedModel.validityEndDate' => :validity_end_date,
      )
    end
  end

  describe '.entity' do
    it { expect(primary_mocked_mapper.entity).to eq(MockedModel) }
  end

  describe '.mapping_with_key_as_array' do
    it 'returns the dot separated mapping keys as an array' do
      expect(secondary_mocked_mapper.mapping_with_key_as_array).to eq(
        %w[sid] => :measure_sid,
        %w[flibble] => :squiloogle,
        %w[mockedModel foo bar] => :qux,
        %w[mockedModel foo baz] => :qaz,
        %w[mockedModel metainfo opType] => :operation,
        %w[mockedModel metainfo origin] => :national,
        %w[mockedModel metainfo transactionDate] => :operation_date,
        %w[mockedModel validityEndDate] => :validity_end_date,
        %w[mockedModel validityStartDate] => :validity_start_date,
      )
    end
  end

  describe '.mapping_keys_to_parse' do
    it 'returns the dot separated mapping keys as an array' do
      expect(secondary_mocked_mapper.mapping_keys_to_parse).to eq(
        [
          %w[mockedModel validityStartDate],
          %w[mockedModel validityEndDate],
          %w[mockedModel metainfo origin],
          %w[mockedModel metainfo opType],
          %w[mockedModel metainfo transactionDate],
          %w[mockedModel foo bar],
          %w[mockedModel foo baz],
        ],
      )
    end
  end

  describe '#parse' do
    subject(:parsed) { secondary_mocked_mapper.new(xml_node).parse.first }

    let(:xml_node) do
      {
        'sid' => '123',
        'flibble' => 'Pratchett',
        'mockedModel' => {
          'validityStartDate' => '1970-01-01T00:00:00',
          'validityEndDate' => '1972-01-01T00:00:00',
          'foo' => {
            'bar' => true,
            'baz' => false,
          },
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2021-01-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00', # TODO: This is an excluded mapping but it appears in the fields
        validity_end_date: '1972-01-01T00:00:00',
        national: true,
        operation: 'U',
        operation_date: '2021-01-29T20:04:37',
        measure_sid: '123',
        squiloogle: 'Pratchett',
        qux: true,
        qaz: false,
      }
    end

    let(:expected_fields) do
      [
        :validity_start_date, # TODO: This is an excluded mapping but it appears in the fields
        :validity_end_date,
        :national,
        :operation,
        :operation_date,
        :measure_sid,
        :squiloogle,
        :qux,
        :qaz,
      ]
    end

    it { expect(parsed[:instance]).to be_a(MockedModel) }
    it { expect(parsed[:instance].values).to eq(expected_values) }
    it { expect(parsed[:instance].fields).to eq(expected_fields) }

    it 'returns the correct expanded_attributes' do
      expected_expanded_attributes = {
        'sid' => '123',
        'flibble' => 'Pratchett',
        'mockedModel' => {
          'validityStartDate' => '1970-01-01T00:00:00',
          'validityEndDate' => '1972-01-01T00:00:00',
          'foo' => {
            'bar' => true,
            'baz' => false,
          },
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2021-01-29T20:04:37',
          },
        },
      }

      expect(parsed[:expanded_attributes]).to eq(expected_expanded_attributes)
    end
  end
end
