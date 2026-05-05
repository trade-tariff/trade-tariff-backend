RSpec.describe MaterializeViewHelper do
  describe '.reload_static_caches' do
    it 'does not error when models do not have static_cache loaded' do
      # In the test environment plugin :static_cache is not applied, so
      # none of the models define load_cache.  reload_static_caches must
      # handle this gracefully via respond_to? rather than blowing up.
      expect { described_class.reload_static_caches }.not_to raise_error
    end

    it 'calls load_cache on models that respond to it' do
      model_name = 'FakeStaticCacheModel'
      model_class = double('model_class', load_cache: nil) # rubocop:disable RSpec/VerifiedDoubles
      allow(model_class).to receive(:respond_to?).with(:load_cache).and_return(true)
      stub_const('MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES', [model_name])
      allow(model_name).to receive(:constantize).and_return(model_class)

      described_class.reload_static_caches

      expect(model_class).to have_received(:load_cache).once
    end

    it 'skips models that do not respond to load_cache' do
      model_name = 'FakeModelWithoutCache'
      model_class = double('model_class') # rubocop:disable RSpec/VerifiedDoubles
      stub_const('MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES', [model_name])
      allow(model_name).to receive(:constantize).and_return(model_class)

      expect { described_class.reload_static_caches }.not_to raise_error
    end
  end

  describe 'STATIC_CACHE_MODEL_NAMES' do
    it 'contains 15 entries' do
      expect(MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES.size).to eq(15)
    end

    it 'every name resolves to an existing constant' do
      expect {
        MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES.each(&:constantize)
      }.not_to raise_error
    end
  end
end
