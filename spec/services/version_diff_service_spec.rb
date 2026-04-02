RSpec.describe VersionDiffService do
  describe '#call' do
    context 'when old_object is nil' do
      it 'returns nil' do
        result = described_class.new('GoodsNomenclatureLabel', nil, { 'description' => 'Fresh apples' }).call
        expect(result).to be_nil
      end
    end

    context 'when objects are identical after filtering' do
      it 'returns nil' do
        obj = { 'description' => 'Fresh apples', 'goods_nomenclature_sid' => '123' }
        result = described_class.new('GoodsNomenclatureLabel', obj, obj).call
        expect(result).to be_nil
      end
    end

    context 'with text changes' do
      it 'produces a word-level text diff for long strings' do
        old_obj = { 'description' => 'Fresh apples, including green and red varieties for consumption' }
        new_obj = { 'description' => 'Fresh oranges, including green and yellow varieties for export' }

        result = described_class.new('GoodsNomenclatureLabel', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[description])

        change = result['changes']['description']
        expect(change['type']).to eq('text')

        ops = change['diff']
        expect(ops).to include(hash_including('op' => 'equal', 'text' => 'Fresh '))
        expect(ops).to include(hash_including('op' => 'delete', 'text' => 'apples,'))
        expect(ops).to include(hash_including('op' => 'insert', 'text' => 'oranges,'))
      end
    end

    context 'with array changes' do
      it 'produces added/removed/unchanged sets' do
        old_obj = { 'synonyms' => %w[apple grape] }
        new_obj = { 'synonyms' => %w[grape banana] }

        result = described_class.new('SomeModel', old_obj, new_obj).call

        change = result['changes']['synonyms']
        expect(change['type']).to eq('array')
        expect(change['added']).to eq(%w[banana])
        expect(change['removed']).to eq(%w[apple])
        expect(change['unchanged']).to eq(%w[grape])
      end
    end

    context 'with simple value changes' do
      it 'produces old/new for booleans' do
        old_obj = { 'stale' => false }
        new_obj = { 'stale' => true }

        result = described_class.new('SomeModel', old_obj, new_obj).call

        change = result['changes']['stale']
        expect(change['type']).to eq('simple')
        expect(change['old']).to be(false)
        expect(change['new']).to be(true)
      end

      it 'produces old/new for short strings' do
        old_obj = { 'status' => 'draft' }
        new_obj = { 'status' => 'published' }

        result = described_class.new('SomeModel', old_obj, new_obj).call

        change = result['changes']['status']
        expect(change['type']).to eq('simple')
        expect(change['old']).to eq('draft')
        expect(change['new']).to eq('published')
      end
    end

    context 'with skipped fields' do
      it 'excludes metadata fields for GoodsNomenclatureLabel' do
        old_obj = {
          'description' => 'Old description that is long enough to be a text diff field',
          'goods_nomenclature_sid' => '100',
          'created_at' => '2024-01-01',
          'context_hash' => 'abc123',
        }
        new_obj = {
          'description' => 'New description that is long enough to be a text diff field',
          'goods_nomenclature_sid' => '200',
          'created_at' => '2024-06-01',
          'context_hash' => 'def456',
        }

        result = described_class.new('GoodsNomenclatureLabel', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[description])
        expect(result['changes']).not_to have_key('goods_nomenclature_sid')
        expect(result['changes']).not_to have_key('created_at')
        expect(result['changes']).not_to have_key('context_hash')
      end

      it 'excludes metadata fields for GoodsNomenclatureSelfText' do
        old_obj = { 'self_text' => 'A' * 50, 'embedding' => [0.1, 0.2], 'similarity_score' => 0.8 }
        new_obj = { 'self_text' => 'B' * 50, 'embedding' => [0.3, 0.4], 'similarity_score' => 0.9 }

        result = described_class.new('GoodsNomenclatureSelfText', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[self_text])
        expect(result['changes']).not_to have_key('embedding')
        expect(result['changes']).not_to have_key('similarity_score')
      end
    end

    context 'with DescriptionIntercept changes' do
      it 'shows array diffs for sources and simple diffs for other fields' do
        old_obj = { 'id' => 1, 'term' => 'footwear', 'sources' => %w[guided_search], 'excluded' => false }
        new_obj = { 'id' => 1, 'term' => 'footwear', 'sources' => %w[guided_search fpo_search], 'excluded' => true }

        result = described_class.new('DescriptionIntercept', old_obj, new_obj).call

        expect(result['changed_fields']).to contain_exactly('sources', 'excluded')
        expect(result['changes']['sources']).to eq(
          'type' => 'array',
          'added' => %w[fpo_search],
          'removed' => [],
          'unchanged' => %w[guided_search],
        )
        expect(result['changes']['excluded']).to eq('type' => 'simple', 'old' => false, 'new' => true)
      end
    end

    context 'with multiple changes' do
      it 'returns all changed fields' do
        old_obj = { 'stale' => false, 'manually_edited' => false }
        new_obj = { 'stale' => true, 'manually_edited' => true }

        result = described_class.new('SomeModel', old_obj, new_obj).call

        expect(result['changed_fields']).to contain_exactly('stale', 'manually_edited')
      end
    end

    context 'with an unknown model type' do
      it 'diffs all fields without skipping any' do
        old_obj = { 'title' => 'Old', 'created_at' => '2024-01-01' }
        new_obj = { 'title' => 'New', 'created_at' => '2024-06-01' }

        result = described_class.new('SearchReference', old_obj, new_obj).call

        expect(result['changed_fields']).to contain_exactly('title', 'created_at')
      end
    end

    context 'with AdminConfiguration virtual fields' do
      it 'extracts selected from nested options value' do
        old_obj = {
          'id' => 1,
          'name' => 'search_model',
          'config_type' => 'nested_options',
          'area' => 'classification',
          'description' => 'Model',
          'value' => { 'selected' => 'gpt-5.2', 'options' => [], 'sub_values' => { 'reasoning_effort' => 'low' } },
        }
        new_obj = old_obj.merge(
          'value' => { 'selected' => 'gpt-5.4', 'options' => [], 'sub_values' => { 'reasoning_effort' => 'low' } },
        )

        result = described_class.new('AdminConfiguration', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[selected])
        expect(result['changes']['selected']).to eq('type' => 'simple', 'old' => 'gpt-5.2', 'new' => 'gpt-5.4')
      end

      it 'extracts sub_values keys as individual fields' do
        old_obj = {
          'id' => 1,
          'name' => 'search_model',
          'config_type' => 'nested_options',
          'area' => 'classification',
          'description' => 'Model',
          'value' => { 'selected' => 'gpt-5.4', 'options' => [], 'sub_values' => { 'reasoning_effort' => 'low' } },
        }
        new_obj = old_obj.merge(
          'value' => { 'selected' => 'gpt-5.4', 'options' => [], 'sub_values' => { 'reasoning_effort' => 'high' } },
        )

        result = described_class.new('AdminConfiguration', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[reasoning_effort])
        expect(result['changes']['reasoning_effort']).to eq('type' => 'simple', 'old' => 'low', 'new' => 'high')
      end

      it 'falls back to raw value for non-hash values' do
        old_obj = {
          'id' => 1,
          'name' => 'some_bool',
          'config_type' => 'boolean',
          'area' => 'classification',
          'description' => 'Toggle',
          'value' => true,
        }
        new_obj = old_obj.merge('value' => false)

        result = described_class.new('AdminConfiguration', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[value])
        expect(result['changes']['value']).to eq('type' => 'simple', 'old' => true, 'new' => false)
      end

      it 'skips id, name, config_type, area, created_at, updated_at' do
        old_obj = {
          'id' => 1,
          'name' => 'test',
          'config_type' => 'boolean',
          'area' => 'classification',
          'description' => 'Toggle',
          'value' => true,
          'created_at' => '2024-01-01',
          'updated_at' => '2024-01-01',
        }
        new_obj = old_obj.merge(
          'id' => 2, 'name' => 'changed', 'config_type' => 'string',
          'area' => 'other', 'value' => false, 'created_at' => '2024-06-01', 'updated_at' => '2024-06-01'
        )

        result = described_class.new('AdminConfiguration', old_obj, new_obj).call

        expect(result['changed_fields']).to eq(%w[value])
      end
    end
  end
end
