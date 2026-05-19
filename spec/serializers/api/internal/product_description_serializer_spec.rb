RSpec.describe Api::Internal::ProductDescriptionSerializer do
  subject(:serialized) { described_class.new(result).serializable_hash.as_json }

  let(:result) do
    Api::Internal::ProductDescription::Result.success(
      description: 'Cotton T-shirt',
      source_url: 'https://example.com/product',
      confidence: 'high',
      metadata: { 'title' => 'Cotton T-shirt' },
    )
  end

  it 'serializes a product description result' do
    expect(serialized).to eq(
      'data' => {
        'id' => 'https://example.com/product',
        'type' => 'product_description',
        'attributes' => {
          'description' => 'Cotton T-shirt',
          'source_url' => 'https://example.com/product',
          'confidence' => 'high',
          'metadata' => { 'title' => 'Cotton T-shirt' },
        },
      },
    )
  end
end
