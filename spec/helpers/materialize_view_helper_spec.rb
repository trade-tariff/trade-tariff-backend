RSpec.describe MaterializeViewHelper do
  describe '.reload_static_caches' do
    it 'calls load_cache on models that respond to it' do
      model_name = 'FakeStaticCacheModel'
      model_class = Class.new { def self.load_cache; end }
      stub_const('MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES', [model_name])
      allow(model_name).to receive(:constantize).and_return(model_class)
      allow(model_class).to receive(:load_cache)

      described_class.reload_static_caches

      expect(model_class).to have_received(:load_cache).once
    end

    it 'skips models that do not respond to load_cache' do
      model_name = 'FakeModelWithoutCache'
      model_class = Class.new
      stub_const('MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES', [model_name])
      allow(model_name).to receive(:constantize).and_return(model_class)

      expect { described_class.reload_static_caches }.not_to raise_error
    end
  end

  describe 'STATIC_CACHE_MODEL_NAMES' do
    it 'contains 15 entries' do
      expect(MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES.size).to eq(15)
    end
  end
end
