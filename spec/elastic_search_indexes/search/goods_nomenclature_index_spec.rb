require 'rails_helper'

RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:index) { described_class.new('testnamespace') }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'testnamespace-goods_nomenclatures-uk' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::GoodsNomenclatureSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record(record) }

    let(:record) { create :heading, :with_description }

    it { is_expected.to include 'goods_nomenclature_item_id' => record.goods_nomenclature_item_id }
  end

  describe '#dataset' do
    subject(:dataset) { described_class.new('testnamespace').dataset }

    before do
      create(:chapter, goods_nomenclature_item_id: '0100000000')                # chapter          -> not included
      create(:heading, :grouping, goods_nomenclature_item_id: '0101000000')     # grouping heading -> not included
      create(:heading, :non_grouping, goods_nomenclature_item_id: '0101000000') # heading          -> not included
      create(:commodity, goods_nomenclature_item_id: '0101210000')              # commodity        -> included
      create(:commodity, :hidden, goods_nomenclature_item_id: '0101210001')     # commodity        -> not included
      create(:commodity, :grouping, goods_nomenclature_item_id: '0101210000')   # subheading       -> not included
    end

    let(:expected_goods_nomenclatures) do
      [
        %w[0101210000 80], # commodity
      ]
    end

    it { is_expected.to be_a(Sequel::Postgres::Dataset) }

    it 'uses the time machine' do
      expect(dataset.sql).to match(/(validity_start_date|validity_end_date)/)
    end

    it 'returns the expected goods nomenclatures' do
      expect(dataset.all.pluck(:goods_nomenclature_item_id, :producline_suffix)).to eq(expected_goods_nomenclatures)
    end
  end

  describe '#definition' do
    context 'when the stemming exclusion and synonym references are specified in the environment' do
      before do
        allow(TradeTariffBackend).to receive_messages(stemming_exclusion_reference_analyzer:, synonym_reference_analyzer:)
      end

      let(:stemming_exclusion_reference_analyzer) { 'analyzers/F135140295' }
      let(:synonym_reference_analyzer) { 'analyzers/F135140296' }

      it 'generates the correct stemmer_override filter setting' do
        expected_filter_setting = {
          type: 'stemmer_override',
          rules_path: 'analyzers/F135140295',
        }

        actual_filter_setting = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :filter,
          :english_stem_exclusions,
        )

        expect(actual_filter_setting).to eq(expected_filter_setting)
      end

      it 'generates the correct synonym filter setting' do
        expected_filter_setting = {
          type: 'synonym',
          synonyms_path: 'analyzers/F135140296',
        }

        actual_filter_setting = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :filter,
          :synonym,
        )

        expect(actual_filter_setting).to eq(expected_filter_setting)
      end

      it 'uses the correct filter order' do
        expected_filter_order = %w[
          synonym
          english_stem_exclusions
          english_possessive_stemmer
          lowercase
          english_stop
          english_stemmer
        ]

        actual_filter_order = index.definition.dig(
          :settings,
          :index,
          :analysis,
          :analyzer,
          :english,
          :filter,
        )

        expect(actual_filter_order).to eq(expected_filter_order)
      end
    end
  end
end
