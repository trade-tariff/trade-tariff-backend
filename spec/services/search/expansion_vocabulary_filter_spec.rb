# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ExpansionVocabularyFilter do
  before do
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)
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

    it 'keeps a singular fold of a query token without vocabulary support' do
      expect(described_class.call(original_query: 'breeding horses', expanded_query: 'breeding horses horse')).to eq('breeding horses horse')
    end

    it 'keeps an ies fold of a query token without vocabulary support' do
      expect(described_class.call(original_query: 'cherry tomatoes', expanded_query: 'cherry tomatoes cherries')).to eq('cherry tomatoes cherries')
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
  end
end
