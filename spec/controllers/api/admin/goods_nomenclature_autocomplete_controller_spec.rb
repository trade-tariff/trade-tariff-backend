RSpec.describe Api::Admin::GoodsNomenclatureAutocompleteController do
  routes { AdminApi.routes }

  describe '#index' do
    before do
      first_match
      second_match
      commodity_match
      non_current_match
      hidden_match
    end

    let!(:first_match) do
      create(
        :goods_nomenclature,
        :with_description,
        :without_indent,
        goods_nomenclature_item_id: '6403000000',
        producline_suffix: '80',
        description: 'Footwear with uppers of leather',
      ).tap do |goods_nomenclature|
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature:,
          value: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_class: 'Chapter',
        )
      end
    end

    let!(:second_match) do
      create(
        :goods_nomenclature,
        :with_description,
        :without_indent,
        goods_nomenclature_item_id: '6404000000',
        producline_suffix: '10',
        description: 'Footwear with uppers of textile materials',
      ).tap do |goods_nomenclature|
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature:,
          value: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_class: 'Heading',
        )
      end
    end

    let(:commodity_match) do
      create(
        :goods_nomenclature,
        :with_description,
        :without_indent,
        goods_nomenclature_item_id: '6406100000',
        producline_suffix: '80',
        description: 'Parts of footwear',
      ).tap do |goods_nomenclature|
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature:,
          value: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_class: 'Commodity',
        )
      end
    end

    let!(:non_current_match) do
      create(
        :goods_nomenclature,
        :with_description,
        :without_indent,
        :non_current,
        goods_nomenclature_item_id: '6405000000',
        description: 'Old footwear record',
      ).tap do |goods_nomenclature|
        create(:search_suggestion, :goods_nomenclature, goods_nomenclature:, value: goods_nomenclature.goods_nomenclature_item_id)
      end
    end

    let(:hidden_match) do
      create(
        :goods_nomenclature,
        :with_description,
        :without_indent,
        goods_nomenclature_item_id: '6407000000',
        description: 'Hidden footwear record',
      ).tap do |goods_nomenclature|
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature:,
          value: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_class: 'Heading',
        )
        create(:hidden_goods_nomenclature, goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end
    end

    it 'returns active goods nomenclatures ordered by item id and producline suffix' do
      get :index, params: { q: '640' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'goods_nomenclature_item_id') }).to eq(%w[6403000000 6404000000 6406100000 6407000000])
    end

    it 'includes the description in the response' do
      get :index, params: { q: '6403' }, format: :json

      json = JSON.parse(response.body)
      expect(json.dig('data', 0, 'attributes')).to include(
        'goods_nomenclature_item_id' => '6403000000',
        'description' => 'Footwear with uppers of leather',
      )
    end

    it 'excludes non-current goods nomenclatures' do
      get :index, params: { q: '640' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'goods_nomenclature_item_id') }).not_to include('6405000000')
    end

    it 'does not exclude hidden goods nomenclatures by exact code' do
      get :index, params: { q: '6407' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'goods_nomenclature_item_id') }).to eq(%w[6407000000])
    end

    it 'excludes chapters hidden by admin configuration' do
      create(
        :admin_configuration,
        name: 'interactive_search_excluded_chapters',
        config_type: 'multi_options',
        value: {
          'selected' => %w[64],
          'options' => [
            { 'key' => '64', 'label' => '64' },
          ],
        },
      )

      get :index, params: { q: '640' }, format: :json

      json = JSON.parse(response.body)
      expect(json['data']).to be_empty
    end

    it 'filters by goods nomenclature class when requested' do
      get :index, params: { q: '640', filter: { goods_nomenclature_class: %w[Chapter Heading] } }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'goods_nomenclature_item_id') }).to eq(%w[6403000000 6404000000 6407000000])
    end
  end
end
