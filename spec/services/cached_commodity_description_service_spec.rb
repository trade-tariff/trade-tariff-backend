RSpec.describe CachedCommodityDescriptionService do
  subject(:service) { described_class.new(code, cache: cache_enabled) }

  let(:codes) { %w[1111111111 2222222222] }
  let(:code) { '2222222222' }
  let(:cache_enabled) { false }

  before do
    create(
      :commodity,
      :expired,
      :with_description,
      goods_nomenclature_item_id: '1111111111',
      goods_nomenclature_sid: 111,
      description: 'Expired commodity description',
    )

    create(
      :commodity,
      :actual,
      :with_description,
      goods_nomenclature_item_id: '2222222222',
      goods_nomenclature_sid: 222,
      description: 'Active commodity<br>description',
    )
  end

  describe '#call' do
    it 'returns an empty string for blank code' do
      expect(described_class.new(nil).call).to eq('')
      expect(described_class.new('').call).to eq('')
    end

    it 'returns normalized description for a single commodity code' do
      expect(service.call).to eq("Active commodity\ndescription")
    end

    it 'returns empty string when no description exists for the commodity code' do
      expect(described_class.new('9999999999').call).to eq('')
    end

    context 'when initialized with cache enabled' do
      let(:cache_enabled) { true }

      it 'uses Rails.cache.fetch for the code key' do
        cache_key = described_class.send(:cache_key, code)

        allow(Rails.cache).to receive(:fetch).and_call_original

        service.call

        expect(Rails.cache).to have_received(:fetch).with(cache_key)
      end
    end
  end

  describe '.fetch_for_codes' do
    it 'returns cached descriptions without calling single-code resolver when all are cached' do
      cache_key_for_111 = described_class.send(:cache_key, '1111111111')
      cache_key_for_222 = described_class.send(:cache_key, '2222222222')

      allow(Rails.cache).to receive(:read_multi)
        .with(cache_key_for_111, cache_key_for_222)
        .and_return(
          cache_key_for_111 => 'Cached 111',
          cache_key_for_222 => 'Cached 222',
        )

      description_service = instance_double(described_class)
      allow(description_service).to receive(:call)
      allow(described_class).to receive(:new).and_return(description_service)
      allow(Rails.cache).to receive(:write_multi)

      result = described_class.fetch_for_codes(codes)

      expect(result).to eq(
        '1111111111' => 'Cached 111',
        '2222222222' => 'Cached 222',
      )
      expect(description_service).not_to have_received(:call)
      expect(Rails.cache).not_to have_received(:write_multi)
    end

    it 'calls single-code resolver for missing codes and writes misses to cache' do
      cache_key_for_111 = described_class.send(:cache_key, '1111111111')
      cache_key_for_222 = described_class.send(:cache_key, '2222222222')

      allow(Rails.cache).to receive(:read_multi)
        .with(cache_key_for_111, cache_key_for_222)
        .and_return(cache_key_for_111 => 'Cached 111')

      allow(GoodsNomenclatureDescription).to receive(:where).and_call_original
      allow(Rails.cache).to receive(:write_multi)

      result = described_class.fetch_for_codes(codes)

      expect(result).to eq(
        '1111111111' => 'Cached 111',
        '2222222222' => "Active commodity\ndescription",
      )
      expect(GoodsNomenclatureDescription).to have_received(:where).with(goods_nomenclature_item_id: %w[2222222222])
      expect(Rails.cache).to have_received(:write_multi).with(
        {
          cache_key_for_222 => "Active commodity\ndescription",
        },
      )
    end
  end
end
