RSpec.describe Evaluation::SyntheticInputSetCreator do
  subject(:set) { described_class.call(name: 'Set A', requested_size: 3, created_by: 'user-123') }

  context 'with enough synthetic ATaRs' do
    before { create_list(:tariff_knowledge_synthetic_atar, 5) }

    it 'saves a set recording who asked for it, and how many were requested and actually used' do
      expect(set).to have_attributes(name: 'Set A', requested_size: 3, actual_size: 3, created_by: 'user-123')
      expect(set.errors).to be_empty
      expect(EvaluationSyntheticInputSet[set.id]).to be_present
    end

    it 'creates one item per sampled synthetic ATaR, each a snapshot of its query and expected code' do
      set
      items = EvaluationSyntheticInputSetItem.where(set_id: set.id).all

      expect(items.size).to eq(3)
      items.each do |item|
        synthetic_atar = TariffKnowledge::SyntheticAtar[item.synthetic_atar_id]
        expect(item.query).to eq(synthetic_atar.description)
        expect(item.expected_code).to eq(synthetic_atar.goods_nomenclature_item_id)
      end
    end

    it 'picks each synthetic ATaR at most once' do
      set
      ids = EvaluationSyntheticInputSetItem.where(set_id: set.id).select_map(:synthetic_atar_id)

      expect(ids.uniq.size).to eq(3)
    end
  end

  context 'when fewer synthetic ATaRs exist than requested' do
    before { create_list(:tariff_knowledge_synthetic_atar, 2) }

    it 'uses all of them and records the real count, instead of erroring' do
      expect(set).to have_attributes(requested_size: 3, actual_size: 2)
      expect(set.errors).to be_empty
      expect(EvaluationSyntheticInputSetItem.where(set_id: set.id).count).to eq(2)
    end
  end

  context 'when there are no synthetic ATaRs at all' do
    it 'creates nothing and says why' do
      expect(set.errors[:requested_size].first).to include('no synthetic ATaRs')
      expect(EvaluationSyntheticInputSet.count).to eq(0)
    end
  end

  context 'when the input is invalid' do
    before { create_list(:tariff_knowledge_synthetic_atar, 3) }

    it 'refuses a blank name' do
      invalid = described_class.call(name: '', requested_size: 2, created_by: 'user-123')

      expect(invalid.errors[:name]).to be_present
      expect(EvaluationSyntheticInputSet.count).to eq(0)
    end

    it 'refuses a name that is already used' do
      create(:evaluation_synthetic_input_set, name: 'Set A')

      expect(set.errors[:name]).to include('is already taken')
    end

    it 'accepts a size sent as text (as a form would)' do
      text_set = described_class.call(name: 'Text', requested_size: '2', created_by: 'user-123')

      expect(text_set.errors).to be_empty
      expect(text_set.actual_size).to eq(2)
    end
  end
end
