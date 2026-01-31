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
end
