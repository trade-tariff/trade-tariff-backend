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
      create(:chapter, goods_nomenclature_item_id: '0100000000')                # chapter          -> included
      create(:heading, :grouping, goods_nomenclature_item_id: '0101000000')     # grouping heading -> not included
      create(:heading, :non_grouping, goods_nomenclature_item_id: '0101000000') # heading          -> included
      create(:commodity, goods_nomenclature_item_id: '0101210000')              # commodity        -> included
      create(:commodity, :grouping, goods_nomenclature_item_id: '0101210000')   # commodity        -> included
    end

    let(:expected_goods_nomenclatures) do
      [
        %w[0100000000 80],
        %w[0101000000 80],
        %w[0101210000 10],
        %w[0101210000 80],
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
    context 'when synonym reference is specified in the environment' do
      before do
        allow(TradeTariffBackend).to receive(:synonym_reference_analyzer).and_return(synonym_reference_analyzer)
      end

      let(:synonym_reference_analyzer) { 'analyzers/F135140295' }

      it 'generates a correct english analyzer setting' do
        expected_analyzer_setting = {
          tokenizer: 'standard',
          filter: %w[
            synonym
            english_possessive_stemmer
            lowercase
            english_stop
            english_stemmer
          ],
        }

        expect(index.definition.dig(:settings, :index, :analysis, :analyzer, :english)).to eq(expected_analyzer_setting)
      end

      it 'generates the correct synonym filter setting' do
        expected_filter_setting = {
          type: 'synonym',
          synonyms_path: 'analyzers/F135140295',
        }

        expect(index.definition.dig(:settings, :index, :analysis, :filter, :synonym)).to eq(expected_filter_setting)
      end
    end

    context 'when synonym reference is `not` specified in the environment' do
      before do
        allow(TradeTariffBackend).to receive(:synonym_reference_analyzer).and_return(synonym_reference_analyzer)
      end

      let(:synonym_reference_analyzer) { nil }

      it 'generates a correct english analyzer setting' do
        expected_analyzer_setting = {
          tokenizer: 'standard',
          filter: %w[
            english_possessive_stemmer
            lowercase
            english_stop
            english_stemmer
          ],
        }

        expect(index.definition.dig(:settings, :index, :analysis, :analyzer, :english)).to eq(expected_analyzer_setting)
      end

      it { expect(index.definition.dig(:settings, :index, :analysis, :filter, :synonym)).to be_nil }
    end

    context 'when the stemming exclusion reference is specified in the environment' do
      before do
        allow(TradeTariffBackend).to receive(:stemming_exclusion_reference_analyzer).and_return(stemming_exclusion_reference_analyzer)
      end

      let(:stemming_exclusion_reference_analyzer) { 'analyzers/F135140295' }

      it 'generates the correct stemmer_override filter setting' do
        expected_filter_setting = {
          type: 'stemmer_override',
          rules_path: 'analyzers/F135140295',
        }

        expect(index.definition.dig(:settings, :index, :analysis, :filter, :english_stem_exclusions)).to eq(expected_filter_setting)
      end

      it 'makes the english_stem_exclusions the first filter' do
        expected_filter_order = %w[
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
