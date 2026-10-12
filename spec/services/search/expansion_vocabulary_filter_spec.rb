# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ExpansionVocabularyFilter do
  before do
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)
    Search::ExpansionVocabulary.reset!
  end

  describe '.call' do
    it 'returns an unchanged expansion when the model did not add text' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken')).to eq('chicken')
    end

    it 'returns a blank expansion unchanged' do
      expect(described_class.call(original_query: 'chicken', expanded_query: ' ')).to eq('')
    end

    it 'returns the original query when the expansion only differs in case' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'Chicken')).to eq('chicken')
    end

    it 'returns the original query when the model rewrote it and nothing is supported' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'zaptoxidinyl serum')).to eq('chicken')
    end

    it 'returns the original query when an appended phrase has an unsupported word' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken zaptoxidinyl cuts')).to eq('chicken')
    end

    it 'keeps a simple plural of a query token without vocabulary support' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken chickens')).to eq('chicken chickens')
    end

    it 'does not guess a singular when the plural has two stems' do
      expect(described_class.call(original_query: 'cases', expanded_query: 'cases cas')).to eq('cases')
      expect(described_class.call(original_query: 'cases', expanded_query: 'cases case')).to eq('cases')
      expect(described_class.call(original_query: 'houses', expanded_query: 'houses hous')).to eq('houses')
    end

    it 'keeps an ies fold of a query token without vocabulary support' do
      expect(described_class.call(original_query: 'cherry tomatoes', expanded_query: 'cherry tomatoes cherries')).to eq('cherry tomatoes cherries')
    end

    it 'returns the original query when the expansion invents an ies fold of a token without a y suffix' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken chickenies')).to eq('chicken')
    end

    it 'returns the original query when the expansion invents a y form of a token without an ies suffix' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken chickeny')).to eq('chicken')
    end

    it 'returns the original query when the expansion invents an es plural of a regular noun' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken chickenes')).to eq('chicken')
    end

    it 'returns the original query when the expansion invents an s plural of an es noun' do
      expect(described_class.call(original_query: 'box', expanded_query: 'box boxs')).to eq('box')
    end

    it 'keeps an es plural of a query token that takes es' do
      expect(described_class.call(original_query: 'box', expanded_query: 'box boxes')).to eq('box boxes')
    end

    it 'keeps the plural of a noun that ends in s' do
      expect(described_class.call(original_query: 'bus', expanded_query: 'bus buses')).to eq('bus buses')
    end

    it 'does not guess the singular of an ambiguous ses plural' do
      expect(described_class.call(original_query: 'buses', expanded_query: 'buses bus')).to eq('buses')
      expect(described_class.call(original_query: 'buses', expanded_query: 'buses buse')).to eq('buses')
    end

    it 'does not pluralize a token that is already plural' do
      expect(described_class.call(original_query: 'chickens', expanded_query: 'chickens chickenss')).to eq('chickens')
      expect(described_class.call(original_query: 'buses', expanded_query: 'buses buseses')).to eq('buses')
    end

    it 'keeps a phrase that only repeats query tokens and stop words' do
      expect(described_class.call(original_query: 'frozen chicken', expanded_query: 'frozen chicken of chicken')).to eq('frozen chicken of chicken')
    end

    context 'with vocabulary records' do
      it 'keeps appended phrases whose words occur in current descriptions' do
        create(:goods_nomenclature_description, description: 'Chickens, frozen cuts of chicken')

        expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken cuts, frozen'))
          .to eq('chicken cuts, frozen')
      end

      it 'drops an expired description' do
        create(:goods_nomenclature_description, description: 'zaptoxidinyl preparations', validity_end_date: 2.years.ago.beginning_of_day)

        expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken zaptoxidinyl'))
          .to eq('chicken')
      end

      it 'does not count a word that only occurs inside another word' do
        create(:goods_nomenclature_description, description: 'Carpets of wool')

        expect(described_class.call(original_query: 'vehicle', expanded_query: 'vehicle car'))
          .to eq('vehicle')
      end

      it 'keeps a rewrite whose words are supported and prefixes the original query' do
        create(:goods_nomenclature_description, description: 'Meat of poultry')

        expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat'))
          .to eq('chicken poultry meat')
      end

      it 'keeps the supported phrases of a rewrite and drops the rest' do
        create(:goods_nomenclature_description, description: 'Meat of poultry')

        expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat, zaptoxidinyl serum'))
          .to eq('chicken poultry meat')
      end

      it 'strips surrounding quotes so a quoted supported term is kept' do
        create(:goods_nomenclature_description, description: 'Meat of poultry')

        expect(described_class.call(original_query: 'chicken', expanded_query: "'poultry' meat"))
          .to eq('chicken poultry meat')
      end

      it 'keeps an internal apostrophe when checking a term' do
        create(:goods_nomenclature_description, description: "Meat at o'clock")

        expect(described_class.call(original_query: 'chicken', expanded_query: "chicken o'clock"))
          .to eq("chicken o'clock")
      end

      it 'drops a whole phrase when one of its words is unsupported' do
        create(:goods_nomenclature_description, description: 'Meat of poultry')

        expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry zaptoxidinyl meat'))
          .to eq('chicken')
      end

      it 'keeps words supported by public search references' do
        create(:search_reference, title: 'woollen jumpers')

        expect(described_class.call(original_query: 'jumper', expanded_query: 'jumper woollen'))
          .to eq('jumper woollen')
      end

      it 'ignores FPO-only search references' do
        reference = create(:search_reference, title: 'zaptoxidinyl resin')
        reference.update(usage: SearchReference::FPO_USAGE)

        expect(described_class.call(original_query: 'resin', expanded_query: 'resin zaptoxidinyl'))
          .to eq('resin')
      end

      it 'keeps words supported by label descriptions, synonyms, colloquial terms and known brands' do
        create(:goods_nomenclature_label, description: 'natural bee honey')
        create(:goods_nomenclature_label, synonyms: Sequel.pg_array(['flower nectar'], :text))
        create(:goods_nomenclature_label, colloquial_terms: Sequel.pg_array(['sweet syrup'], :text))
        create(:goods_nomenclature_label, known_brands: Sequel.pg_array(['brandine honey'], :text))

        expect(described_class.call(original_query: 'honey', expanded_query: 'honey natural, nectar, syrup, brandine'))
          .to eq('honey natural, nectar, syrup, brandine')
      end

      it 'ignores expired labels' do
        create(:goods_nomenclature_label, description: 'zaptoxidinyl wax', expired: true)

        expect(described_class.call(original_query: 'wax', expanded_query: 'wax zaptoxidinyl'))
          .to eq('wax')
      end

      context 'with ATaR rulings' do
        before do
          allow(AdminConfiguration).to receive(:enabled?).and_call_original
          create(:tariff_knowledge_public_atar_ruling, keywords: Sequel.pg_array(['artificial knees'], :text))
        end

        it 'keeps words supported by ATaR search terms when ATaR search is enabled' do
          allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(true)

          expect(described_class.call(original_query: 'knee', expanded_query: 'knee artificial'))
            .to eq('knee artificial')
        end

        it 'ignores ATaR search terms when ATaR search is disabled' do
          allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)

          expect(described_class.call(original_query: 'knee', expanded_query: 'knee artificial'))
            .to eq('knee')
        end

        it 'ignores an ATaR ruling that is not current' do
          allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(true)
          TariffKnowledge::PublicAtarRuling.dataset.delete
          create(:tariff_knowledge_public_atar_ruling, keywords: Sequel.pg_array(['obsolete knees'], :text), validity_end_date: 1.year.ago.to_date)

          expect(described_class.call(original_query: 'knee', expanded_query: 'knee obsolete')).to eq('knee')
        end
      end
    end

    it 'is idempotent on its own output' do
      create(:goods_nomenclature_description, description: 'Meat of poultry')

      once = described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')

      expect(described_class.call(original_query: 'chicken', expanded_query: once)).to eq(once)
    end

    it 'returns the original query when the vocabulary lookup fails' do
      allow(Sequel::Model).to receive(:db).and_raise(Sequel::DatabaseError)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken cuts, frozen'))
        .to eq('chicken')
    end

    it 'does not let a substituted rewrite through when the vocabulary lookup fails' do
      allow(Sequel::Model).to receive(:db).and_raise(Sequel::DatabaseError)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')).to eq('chicken')
    end

    it 'returns the original query when the added text has no phrases' do
      expect(described_class.call(original_query: 'chicken', expanded_query: 'chicken , ,')).to eq('chicken')
    end

    it 'returns the original query when the vocabulary set is not loaded yet' do
      allow(Search::ExpansionVocabulary).to receive(:supported_words).and_return(nil)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')).to eq('chicken')
    end

    it 'does not query the database when a vocabulary snapshot is already loaded' do
      Search::ExpansionVocabulary.remember!(%w[poultry meat])
      allow(Sequel::Model).to receive(:db).and_raise(Sequel::DatabaseError)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat'))
        .to eq('chicken poultry meat')
    end

    it 'does not build a vocabulary in a worker process' do
      allow(Sidekiq).to receive(:server?).and_return(true)
      expect(Sequel::Model).not_to receive(:db)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')).to eq('chicken')
    end

    it 'uses a shared vocabulary in a worker without retaining it' do
      memory_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_cache)
      allow(Sidekiq).to receive(:server?).and_return(true)
      Rails.cache.write("search_expansion_vocabulary/v1/#{Date.current}/false", %w[poultry meat])
      expect(Sequel::Model).not_to receive(:db)

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat'))
        .to eq('chicken poultry meat')
      expect(Search::ExpansionVocabulary.instance_variable_get(:@snapshot)).to be_nil
    end

    it 'does not use a shared vocabulary from another date' do
      memory_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_cache)
      allow(Sidekiq).to receive(:server?).and_return(true)
      Rails.cache.write("search_expansion_vocabulary/v1/#{Date.current - 1}/false", %w[poultry])

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')).to eq('chicken')
    end

    it 'does not duplicate the original query when the expansion prefix differs only in case' do
      create(:goods_nomenclature_description, description: 'Meat of poultry')

      expect(described_class.call(original_query: 'chicken', expanded_query: 'Chicken poultry')).to eq('chicken poultry')
    end

    it 'keeps the original query for a past date and does not scan' do
      expect(Sequel::Model).not_to receive(:db)
      TradeTariffRequest.time_machine_now = 2.years.ago

      expect(described_class.call(original_query: 'chicken', expanded_query: 'poultry meat')).to eq('chicken')
    end
  end
end
