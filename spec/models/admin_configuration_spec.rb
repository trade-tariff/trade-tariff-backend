RSpec.describe AdminConfiguration do
  describe '.classification' do
    before do
      create(:admin_configuration, name: 'class_config', area: 'classification')
      create(:admin_configuration, name: 'other_config', area: 'other')
    end

    it 'returns only configurations with area classification' do
      names = described_class.classification.select_map(:name)
      expect(names).to eq(%w[class_config])
    end
  end

  describe '.by_name' do
    let!(:config) { create(:admin_configuration, name: 'test_lookup', value: 'found') }

    it 'returns the configuration matching the given name' do
      result = described_class.classification.by_name('test_lookup')
      expect(result.name).to eq('test_lookup')
      expect(result.value).to eq('found')
    end

    it 'returns nil when no configuration matches' do
      result = described_class.classification.by_name('nonexistent')
      expect(result).to be_nil
    end

    context 'with memory cache store' do
      let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
      end

      it 'caches the result for subsequent calls' do
        described_class.classification.by_name('test_lookup')

        config.update(value: 'updated')
        described_class.refresh!(concurrently: false)

        cached = described_class.classification.by_name('test_lookup')
        expect(cached.value).to eq('found')
      end

      it 'returns fresh data after cache is cleared' do
        described_class.classification.by_name('test_lookup')

        config.update(value: 'updated')
        described_class.refresh!(concurrently: false)

        memory_store.delete('admin_configurations/test_lookup')

        fresh = described_class.classification.by_name('test_lookup')
        expect(fresh.value).to eq('updated')
      end
    end
  end

  describe 'validations' do
    subject(:config) { build(:admin_configuration, **attrs) }

    let(:attrs) { {} }

    context 'when valid' do
      it 'passes validation' do
        expect(config).to be_valid
      end
    end

    context 'when name is blank' do
      let(:attrs) { { name: nil } }

      it 'is invalid' do
        expect(config).not_to be_valid
        expect(config.errors[:name]).to be_present
      end
    end

    context 'when description is blank' do
      let(:attrs) { { description: nil } }

      it 'is invalid' do
        expect(config).not_to be_valid
        expect(config.errors[:description]).to be_present
      end
    end

    context 'when config_type is invalid' do
      let(:attrs) { { config_type: 'unknown' } }

      it 'is invalid' do
        expect(config).not_to be_valid
        expect(config.errors[:config_type]).to be_present
      end
    end

    describe 'boolean value validation' do
      let(:attrs) { { config_type: 'boolean', value: value } }

      context 'with true' do
        let(:value) { true }

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context 'with false' do
        let(:value) { false }

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context 'with string "true"' do
        let(:value) { 'true' }

        it 'is valid after normalization' do
          expect(config).to be_valid
        end
      end
    end

    describe 'text value validation' do
      let(:attrs) { { config_type: config_type, value: value } }

      context 'when string type with blank value' do
        let(:config_type) { 'string' }
        let(:value) { '' }

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end

      context 'when markdown type with blank value' do
        let(:config_type) { 'markdown' }
        let(:value) { '' }

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end

      context 'when string type with present value' do
        let(:config_type) { 'string' }
        let(:value) { 'hello' }

        it 'is valid' do
          expect(config).to be_valid
        end
      end
    end

    describe 'integer value validation' do
      let(:attrs) { { config_type: 'integer', value: value } }

      context "with string '250'" do
        let(:value) { '250' }

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context 'with integer 250' do
        let(:value) { 250 }

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context "with negative string '-1'" do
        let(:value) { '-1' }

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context "with non-numeric string 'abc'" do
        let(:value) { 'abc' }

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end

      context "with decimal string '12.5'" do
        let(:value) { '12.5' }

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end
    end

    describe 'integer normalization' do
      it "normalizes string '250' to integer 250" do
        config = build(:admin_configuration, :integer, value: '250')
        config.valid?
        expect(config[:value].to_i).to eq(250)
      end
    end

    describe 'options value validation' do
      let(:attrs) { { config_type: 'options', value: value } }

      context 'with valid options hash' do
        let(:value) do
          {
            'selected' => 'a',
            'options' => [{ 'key' => 'a', 'label' => 'A' }],
          }
        end

        it 'is valid' do
          expect(config).to be_valid
        end
      end

      context 'with empty options array' do
        let(:value) do
          { 'selected' => '', 'options' => [] }
        end

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end

      context 'with non-hash value' do
        let(:value) { 'not a hash' }

        it 'is invalid' do
          expect(config).not_to be_valid
          expect(config.errors[:value]).to be_present
        end
      end
    end

    describe 'unique name' do
      before { create(:admin_configuration, name: 'taken_name') }

      it 'rejects duplicate names' do
        config = build(:admin_configuration, name: 'taken_name')
        expect(config).not_to be_valid
        expect(config.errors[:name]).to include('is already taken')
      end
    end
  end

  describe '#selected_option' do
    subject(:config) { create(:admin_configuration, :options, value: value) }

    context 'with hash containing selected value' do
      let(:value) { { 'selected' => 'gpt-4', 'options' => [{ 'key' => 'gpt-4' }] } }

      it 'returns the selected value' do
        expect(config.selected_option).to eq('gpt-4')
      end
    end

    context 'with hash containing blank selected value' do
      let(:value) { { 'selected' => '', 'options' => [{ 'key' => 'gpt-4' }] } }

      it 'returns the default' do
        expect(config.selected_option(default: 'fallback')).to eq('fallback')
      end
    end

    context 'with nil value' do
      let(:config) { build(:admin_configuration, :options, value: nil) }

      it 'returns the default' do
        expect(config.selected_option(default: 'fallback')).to eq('fallback')
      end
    end

    context 'when reloaded from database (JSONBHash)' do
      let(:value) { { 'selected' => 'gpt-4o', 'options' => [{ 'key' => 'gpt-4o' }] } }

      it 'returns the selected value from JSONBHash' do
        config.reload
        expect(config.selected_option).to eq('gpt-4o')
      end
    end
  end

  describe '#enabled?' do
    subject(:config) { create(:admin_configuration, :boolean, value: value) }

    context 'when value is true' do
      let(:value) { true }

      it 'returns true' do
        expect(config.enabled?).to be true
      end
    end

    context 'when value is false' do
      let(:value) { false }

      it 'returns false' do
        expect(config.enabled?).to be false
      end
    end

    context 'when value is nil' do
      let(:config) { build(:admin_configuration, :boolean, value: nil) }

      it 'returns the default (true by default)' do
        expect(config.enabled?).to be true
      end

      it 'returns the specified default when false' do
        expect(config.enabled?(default: false)).to be false
      end
    end

    context 'when reloaded from database' do
      let(:value) { false }

      it 'returns the correct value from database' do
        config.reload
        expect(config.enabled?).to be false
      end
    end
  end

  describe '.default_for' do
    it 'returns static values directly' do
      expect(described_class.default_for('opensearch_result_limit')).to eq(30)
    end

    it 'resolves lambda values' do
      allow(TradeTariffBackend).to receive(:ai_model).and_return('gpt-5.2')
      expect(described_class.default_for('search_model')).to eq('gpt-5.2')
    end

    it 'raises KeyError for unknown names' do
      expect { described_class.default_for('nonexistent') }.to raise_error(KeyError)
    end

    it 'accepts symbol keys' do
      expect(described_class.default_for(:pos_noun_boost)).to eq(10)
    end
  end

  describe '.enabled?' do
    context 'when config record is missing' do
      it 'returns the default value' do
        expect(described_class.enabled?('expand_search_enabled')).to be true
        expect(described_class.enabled?('interactive_search_enabled')).to be false
      end
    end

    context 'when config record exists' do
      before do
        create(:admin_configuration, :boolean, name: 'expand_search_enabled', value: false, area: 'classification')
      end

      it 'returns the config value' do
        expect(described_class.enabled?('expand_search_enabled')).to be false
      end
    end
  end

  describe '.integer_value' do
    context 'when config record is missing' do
      it 'returns the default value' do
        expect(described_class.integer_value('opensearch_result_limit')).to eq(30)
        expect(described_class.integer_value('pos_noun_boost')).to eq(10)
        expect(described_class.integer_value('search_result_limit')).to eq(5)
      end
    end

    context 'when config record exists' do
      before do
        create(:admin_configuration, :integer, name: 'opensearch_result_limit', value: 50, area: 'classification')
      end

      it 'returns the configured integer value' do
        expect(described_class.integer_value('opensearch_result_limit')).to eq(50)
      end
    end
  end

  describe '.option_value' do
    context 'when config record is missing' do
      it 'returns the default value' do
        allow(TradeTariffBackend).to receive(:ai_model).and_return('gpt-5.2')
        expect(described_class.option_value('search_model')).to eq('gpt-5.2')
      end
    end

    context 'when config record exists' do
      before do
        create(:admin_configuration, :options,
               name: 'search_model',
               area: 'classification',
               value: {
                 'selected' => 'gpt-4.1-mini-2025-04-14',
                 'options' => [{ 'key' => 'gpt-4.1-mini-2025-04-14', 'label' => 'GPT-4.1 Mini' }],
               })
      end

      it 'returns the selected option' do
        expect(described_class.option_value('search_model')).to eq('gpt-4.1-mini-2025-04-14')
      end
    end
  end

  describe 'expand search cache invalidation' do
    context 'when saving expand_query_context config' do
      let!(:config) { create(:admin_configuration, :markdown, name: 'expand_query_context') }

      it 'clears the expand search cache' do
        allow(ExpandSearchQueryService).to receive(:clear_cache!)

        config.update(value: 'new context')

        expect(ExpandSearchQueryService).to have_received(:clear_cache!).once
      end
    end

    context 'when saving expand_model config' do
      let!(:config) { create(:admin_configuration, :options, name: 'expand_model') }

      it 'clears the expand search cache' do
        allow(ExpandSearchQueryService).to receive(:clear_cache!)

        config.update(value: { 'selected' => 'gpt-4o', 'options' => [{ 'key' => 'gpt-4o' }] })

        expect(ExpandSearchQueryService).to have_received(:clear_cache!).once
      end
    end

    context 'when saving an unrelated config' do
      let!(:config) { create(:admin_configuration, :boolean, name: 'other_config') }

      it 'does not clear the expand search cache' do
        allow(ExpandSearchQueryService).to receive(:clear_cache!)

        config.update(value: true)

        expect(ExpandSearchQueryService).not_to have_received(:clear_cache!)
      end
    end
  end
end
