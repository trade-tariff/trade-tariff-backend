require 'rails_helper'

RSpec.describe Evaluation::GoldQueryItem do
  include GoldQueryItemHelper

  let(:gold_query_set) { create(:evaluation_gold_query_set) }

  def versions_of(item)
    Version.where(item_type: 'EvaluationGoldQuery', item_id: item.rows.map { |row| row.id.to_s })
  end

  describe '.for_set' do
    it 'groups the three persona rows of a source item into one item' do
      create_gold_query_item(gold_query_set, source_id: '600000001')

      items = described_class.for_set(gold_query_set)

      expect(items.size).to eq(1)
      expect(items.first.rows.map(&:persona)).to eq(%w[emu_generic emu_ordinary emu_specific])
    end

    it 'orders items by source type and then by source id, treating ids as numbers' do
      create_gold_query_item(gold_query_set, source_type: 'synthetic_atar', source_id: '10')
      create_gold_query_item(gold_query_set, source_type: 'synthetic_atar', source_id: '9')
      create_gold_query_item(gold_query_set, source_type: 'atar', source_id: '600000002')

      expect(described_class.for_set(gold_query_set).map(&:id)).to eq(%w[atar-600000002 synthetic_atar-9 synthetic_atar-10])
    end

    it 'leaves out the items of other sets' do
      create_gold_query_item(create(:evaluation_gold_query_set))

      expect(described_class.for_set(gold_query_set)).to eq([])
    end
  end

  describe '.find' do
    before { create_gold_query_item(gold_query_set, source_type: 'synthetic_atar', source_id: '7') }

    it 'finds an item from its id' do
      expect(described_class.find(gold_query_set, 'synthetic_atar-7').rows.size).to eq(3)
    end

    it 'raises when the item is in a different set' do
      expect { described_class.find(create(:evaluation_gold_query_set), 'synthetic_atar-7') }.to raise_error(Sequel::NoMatchingRow)
    end

    ['synthetic_atar-8', 'atar-7', 'synthetic_atar', '7', ''].each do |id|
      it "raises for the unknown id #{id.inspect}" do
        expect { described_class.find(gold_query_set, id) }.to raise_error(Sequel::NoMatchingRow)
      end
    end
  end

  describe 'reading an item' do
    subject(:item) { described_class.find(gold_query_set, 'atar-600000001') }

    before do
      create_gold_query_item(gold_query_set, expected_code: '6302100000', queries: { 'emu_ordinary' => 'cotton bed sheets' })
      EvaluationGoldQuery.where(persona: 'emu_specific').update(notes: 'checked with the analysts')
    end

    it 'takes its id from the source type and source id' do
      expect(item.id).to eq('atar-600000001')
      expect(item.gold_query_set_id).to eq(gold_query_set.id)
      expect(item.source_type).to eq('atar')
      expect(item.source_id).to eq('600000001')
    end

    it 'shares the expected code and the source text across the three rows' do
      expect(item.expected_code).to eq('6302100000')
      expect(item.oracle_text).to eq('Bed linen woven from cotton fabric, printed with a floral pattern.')
    end

    it 'gives the query and notes of each persona' do
      expect(item.query_for('emu_ordinary')).to eq('cotton bed sheets')
      expect(item.notes_for('emu_specific')).to eq('checked with the analysts')
      expect(item.notes_for('emu_generic')).to be_nil
    end

    it 'has no real user search for an ATaR' do
      expect(item.real_user_search).to be_nil
    end

    context 'when the item comes from a synthetic ATaR' do
      subject(:item) { described_class.find(gold_query_set, "synthetic_atar-#{synthetic_atar.id}") }

      let(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'a made up search') }

      before { create_gold_query_item(gold_query_set, source_type: 'synthetic_atar', source_id: synthetic_atar.id.to_s) }

      it 'reads the real user search from the synthetic ATaR' do
        expect(item.real_user_search).to eq('a made up search')
      end

      it 'has none when the synthetic ATaR has since been deleted' do
        synthetic_atar.destroy

        expect(item.real_user_search).to be_nil
      end
    end
  end

  describe '#update' do
    subject(:item) { described_class.find(gold_query_set, 'atar-600000001') }

    before do
      create_gold_query_item(gold_query_set, expected_code: '6302100000')
      TradeTariffRequest.whodunnit = 'operator-1'
    end

    after { TradeTariffRequest.reset }

    it 'changes one persona query and writes history only for that row' do
      expect(item.update(emu_generic_query: 'bed sheets')).to be(true)

      expect(item.query_for('emu_generic')).to eq('bed sheets')
      expect(EvaluationGoldQuery.where(query: 'bed sheets').count).to eq(1)
      expect(versions_of(item).where(event: 'update').select_map(:whodunnit)).to eq(%w[operator-1])
    end

    it 'saves an expected code change to all three rows, each with its own history entry' do
      expect(item.update(expected_code: '6302100090')).to be(true)

      expect(EvaluationGoldQuery.where(set_id: gold_query_set.id).select_map(:expected_code)).to eq(%w[6302100090] * 3)
      expect(versions_of(item).where(event: 'update').count).to eq(3)
    end

    it 'saves a query and a note together' do
      item.update(emu_specific_query: 'printed cotton bed sheets', emu_specific_notes: 'reworded')

      row = EvaluationGoldQuery.first(persona: 'emu_specific')
      expect(row.values).to include(query: 'printed cotton bed sheets', notes: 'reworded')
    end

    it 'removes surrounding spaces and stores a blank note as no note' do
      EvaluationGoldQuery.where(persona: 'emu_generic').update(notes: 'old note')

      item.update(emu_generic_query: '  bed sheets  ', emu_generic_notes: '   ', expected_code: ' 6302100090 ')

      row = EvaluationGoldQuery.first(persona: 'emu_generic')
      expect(row.values).to include(query: 'bed sheets', notes: nil, expected_code: '6302100090')
    end

    it 'leaves a value alone when its key is not sent' do
      item.update(emu_generic_query: 'bed sheets')

      expect(item.expected_code).to eq('6302100000')
      expect(item.query_for('emu_ordinary')).to eq('emu_ordinary search')
    end

    it 'writes no history when nothing changed' do
      expect { item.update(emu_generic_query: 'emu_generic search', expected_code: '6302100000') }.not_to(change { versions_of(item).count })
    end

    { '6 digits' => '630210', '8 digits' => '63021000', '10 digits' => '6302100090' }.each do |label, code|
      it "accepts an expected code of #{label}" do
        expect(item.update(expected_code: code)).to be(true)
      end
    end

    ['63021', '630210000', '6302 100000', '63021000AB', '630210000000'].each do |code|
      it "refuses the expected code #{code.inspect} and saves nothing" do
        expect(item.update(expected_code: code, emu_generic_query: 'bed sheets')).to be(false)

        expect(item.errors[:expected_code]).to eq(['must be 6, 8 or 10 digits'])
        expect(EvaluationGoldQuery.where(query: 'bed sheets').count).to eq(0)
        expect(EvaluationGoldQuery.where(expected_code: code).count).to eq(0)
      end
    end

    it 'gives one error, not three, for a blank expected code' do
      expect(item.update(expected_code: '')).to be(false)

      expect(item.errors[:expected_code]).to eq(['is not present'])
    end

    it 'refuses a blank query, names the persona, and saves none of the other changes' do
      expect(item.update(emu_generic_query: '  ', emu_ordinary_query: 'bed sheets')).to be(false)

      expect(item.errors[:emu_generic_query]).to eq(['is not present'])
      expect(item.errors.keys).to eq([:emu_generic_query])
      expect(EvaluationGoldQuery.where(query: 'bed sheets').count).to eq(0)
    end

    it 'does not check the format of an expected code that was not changed' do
      EvaluationGoldQuery.where(set_id: gold_query_set.id).update(expected_code: '6302')

      expect(described_class.find(gold_query_set, 'atar-600000001').update(emu_generic_query: 'bed sheets')).to be(true)
    end

    it 'ignores keys that are not editable' do
      item.update(emu_generic_query: 'bed sheets', oracle_text: 'something else', source_id: '1', persona: 'x')

      expect(EvaluationGoldQuery.select_map(:oracle_text).uniq).to eq(['Bed linen woven from cotton fabric, printed with a floral pattern.'])
      expect(EvaluationGoldQuery.select_map(:source_id).uniq).to eq(%w[600000001])
    end
  end

  describe '#destroy' do
    subject(:item) { described_class.find(gold_query_set, 'atar-600000001') }

    before do
      create_gold_query_item(gold_query_set, source_id: '600000001')
      create_gold_query_item(gold_query_set, source_id: '600000002')
    end

    it 'deletes the three rows of this item only' do
      expect { item.destroy }.to change(EvaluationGoldQuery, :count).by(-3)
      expect(EvaluationGoldQuery.select_map(:source_id).uniq).to eq(%w[600000002])
    end

    it 'writes a destroy history entry for each row' do
      rows = item.rows
      item.destroy

      expect(Version.where(item_type: 'EvaluationGoldQuery', item_id: rows.map { |row| row.id.to_s }, event: 'destroy').count).to eq(3)
    end
  end

  describe '#versions' do
    subject(:item) { described_class.find(gold_query_set, 'atar-600000001') }

    before { create_gold_query_item(gold_query_set) }

    it 'lists the history of all three rows, newest first' do
      item.update(emu_specific_query: 'first edit')
      item.update(emu_generic_query: 'second edit')

      versions = item.versions.all

      expect(versions.size).to eq(5)
      expect(versions.map(&:id)).to eq(versions.map(&:id).sort.reverse)
      expect(versions.first.object['query']).to eq('second edit')
    end

    it 'leaves out the history of other items' do
      create_gold_query_item(gold_query_set, source_id: '600000002')

      expect(item.versions.count).to eq(3)
    end
  end
end
