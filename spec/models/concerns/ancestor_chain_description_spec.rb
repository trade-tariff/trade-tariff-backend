RSpec.describe AncestorChainDescription do
  around { |example| TimeMachine.now { example.run } }

  describe '#ancestor_chain_description' do
    subject(:ancestor_chain_description) { commodity.ancestor_chain_description }

    let(:chapter) { create(:chapter, :with_description, description: 'Live animals') }
    let(:heading) { create(:heading, :with_description, description: 'Live horses') }
    let(:commodity) do
      create(:commodity, :with_description, description: 'Pure-bred breeding animals').tap do |c|
        allow(c).to receive(:ancestors).and_return([chapter, heading])
      end
    end

    it 'joins ancestor descriptions with current description using " >> "' do
      expect(ancestor_chain_description).to eq('Live animals >> Live horses >> Pure-bred breeding animals')
    end

    context 'when an ancestor has blank description' do
      let(:blank_ancestor) { instance_double(GoodsNomenclature, description_html: '') }

      let(:commodity) do
        create(:commodity, :with_description, description: 'Pure-bred breeding animals').tap do |c|
          allow(c).to receive(:ancestors).and_return([chapter, blank_ancestor, heading])
        end
      end

      it 'filters out blank descriptions' do
        expect(ancestor_chain_description).to eq('Live animals >> Live horses >> Pure-bred breeding animals')
        expect(ancestor_chain_description).not_to include(' >>  >> ')
      end
    end

    context 'when there are no ancestors' do
      let(:commodity) do
        create(:commodity, :with_description, description: 'Standalone item').tap do |c|
          allow(c).to receive(:ancestors).and_return([])
        end
      end

      it 'returns just the current description' do
        expect(ancestor_chain_description).to eq('Standalone item')
      end
    end
  end
end
