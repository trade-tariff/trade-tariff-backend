RSpec.describe JsonapiSerializerQueryOptions do
  before do
    stub_const('JsonapiQueryOptionsRelatedSerializer', Class.new do
      include JSONAPI::Serializer

      set_type :related
      attributes :name
    end)

    stub_const('JsonapiQueryOptionsTestSerializer', Class.new do
      include JSONAPI::Serializer

      set_type :thing
      attributes :name, :description
      has_one :related, serializer: JsonapiQueryOptionsRelatedSerializer
    end)
  end

  after do
    Thread.current[:jsonapi_query_options] = nil
  end

  let(:related_resource_class) { Data.define(:id, :name) }
  let(:test_resource_class) do
    Data.define(:id, :name, :description, :related) do
      delegate :id, to: :related, prefix: true
    end
  end
  let(:related) { related_resource_class.new(id: 2, name: 'related') }
  let(:resource) { test_resource_class.new(id: 1, name: 'name', description: 'description', related:) }

  it 'preserves existing serializer options when no request query options are present' do
    result = JsonapiQueryOptionsTestSerializer.new(resource, include: [:related]).serializable_hash

    expect(result[:data][:attributes]).to eq(name: 'name', description: 'description')
    expect(result[:included]).to contain_exactly(
      hash_including(type: :related, attributes: { name: 'related' }),
    )
  end

  it 'applies request scoped sparse fieldsets to every serializer' do
    Thread.current[:jsonapi_query_options] = {
      include_requested: false,
      include: nil,
      fields: { thing: %i[name] },
    }

    result = JsonapiQueryOptionsTestSerializer.new(resource).serializable_hash

    expect(result[:data][:attributes]).to eq(name: 'name')
  end

  it 'removes serializer includes for relationships excluded by sparse fieldsets' do
    Thread.current[:jsonapi_query_options] = {
      include_requested: false,
      include: nil,
      fields: { thing: %i[name] },
    }

    result = JsonapiQueryOptionsTestSerializer.new(resource, include: [:related]).serializable_hash

    expect(result).not_to have_key(:included)
  end

  it 'treats an explicitly empty include param as no compound documents' do
    Thread.current[:jsonapi_query_options] = {
      include_requested: true,
      include: [],
      fields: {},
    }

    result = JsonapiQueryOptionsTestSerializer.new(resource, include: [:related]).serializable_hash

    expect(result).not_to have_key(:included)
  end

  it 'rejects unsupported requested includes before serialization' do
    Thread.current[:jsonapi_query_options] = {
      include_requested: true,
      include: %w[missing_relationship],
      fields: {},
    }

    expect { JsonapiQueryOptionsTestSerializer.new(resource).serializable_hash }
      .to raise_error(JSONAPI::Serializer::UnsupportedIncludeError)
  end
end
