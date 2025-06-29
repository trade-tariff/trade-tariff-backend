RSpec.describe TreeIntegrityCheckingService do
  let(:instance) { described_class.new }
  let(:commodity) { create :commodity, :with_chapter_and_heading }

  describe '#check!' do
    subject { instance.check! }

    before { commodity }

    context 'without tree break' do
      it { is_expected.to be true }
    end

    context 'with tree break' do
      let(:commodity) { create :commodity, :with_chapter_and_heading, indents: 2 }

      it { is_expected.to be false }

      it 'tracks failures' do
        instance.check!

        expect(instance.failures).to eq \
          Set.new([commodity.heading, commodity].map(&:goods_nomenclature_sid))
      end
    end

    context 'with missing indents' do
      before do
        commodity.goods_nomenclature_indent.destroy
        GoodsNomenclatures::TreeNode.refresh!
      end

      it { is_expected.to be false }

      it 'tracks sid with missing indent' do
        instance.check!

        expect(instance.failures).to eq Set.new([commodity.goods_nomenclature_sid])
      end
    end
  end
end
