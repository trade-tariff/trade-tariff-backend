RSpec.describe MaterializeViewHelper do
  describe '.reload_static_caches' do
    context 'when in the test environment' do
      it 'does nothing and raises no error' do
        # The guard `return if Rails.env.test?` short-circuits the method so
        # no constantize calls are attempted and no load_cache is fired.
        expect { described_class.reload_static_caches }.not_to raise_error
      end
    end

    context 'when outside the test environment' do
      before { allow(Rails.env).to receive(:test?).and_return(false) }

      it 'calls load_cache on every model listed in STATIC_CACHE_MODEL_NAMES' do
        MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES.each do |name|
          allow(name.constantize).to receive(:load_cache)
        end

        described_class.reload_static_caches

        MaterializeViewHelper::STATIC_CACHE_MODEL_NAMES.each do |name|
          expect(name.constantize).to have_received(:load_cache).once
        end
      end
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
