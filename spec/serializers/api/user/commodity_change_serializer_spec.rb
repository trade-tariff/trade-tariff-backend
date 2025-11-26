# frozen_string_literal: true

RSpec.describe Api::User::CommodityChangeSerializer do
  let(:object) { OpenStruct.new(id: 'commodity_endings', description: 'desc', count: 2) }
  let(:serializer) { described_class.new([object]) }

  it 'serializes the object correctly' do
    result = serializer.serializable_hash
    expect(result[:data].first[:id]).to eq('commodity_endings')
    expect(result[:data].first[:type]).to eq(:commodity_change)
    expect(result[:data].first[:attributes]).to include(description: 'desc', count: 2)
  end
end
