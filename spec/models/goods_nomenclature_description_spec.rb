RSpec.describe GoodsNomenclatureDescription do
  describe '#description' do
    subject(:goods_nomenclature_description) { build :goods_nomenclature_description, description: }

    context 'when the description value is nil' do
      let(:description) { nil }

      it { expect(goods_nomenclature_description.description).to eq('') }
    end

    context 'when the description value has multiple chained <br><br><br>tags' do
      let(:description) do
        'Additives containing<br> <br><br><br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br> <br><br><br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'replaces the chain of <br> tags with a single <br> tag' do
        expected = 'Additives containing<br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
        expect(goods_nomenclature_description.description).to eq(expected)
      end
    end

    context 'when the description value has only single <br> tag chains' do
      let(:description) do
        'Additives containing<br>- overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and<br>- by weight more than 25 % but not more than 50 % of mineral oils,<br>having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'does not change the description' do
        expect(goods_nomenclature_description.description).to eq(description)
      end
    end

    context 'when the description value has no <br> tags' do
      let(:description) do
        'Additives containing - overbased magnesium (C20-C24) alkylbenzenesulphonates (CAS RN 231297-75-9) and - by weight more than 25 % but not more than 50 % of mineral oils,having a total base number of more than 350, but not more than 450, for use in the manufacture of lubricating oils'
      end

      it 'does not change the description' do
        expect(goods_nomenclature_description.description).to eq(description)
      end
    end
  end

  describe '#description_indexed' do
    it 'removes negation' do
      goods_nomenclature_description = build(
        :goods_nomenclature_description,
        description: 'some Thing text, not other text',
      )

      expect(goods_nomenclature_description.description_indexed).to eq('some thing text')
    end
  end

  describe '#description_plain' do
    it 'returns a plain description capitalized' do
      goods_nomenclature_description = build(
        :goods_nomenclature_description,
        description: 'LIVE ANIMALS',
      )

      expect(goods_nomenclature_description.description_plain).to eq('Live animals')
    end
  end

  describe '#to_s' do
    let(:gono_description) { build :goods_nomenclature_description }

    it 'is an alias for description' do
      expect(gono_description.to_s).to eq gono_description.description
    end
  end

  describe '#consigned_from' do
    subject(:goods_nomenclature_description) { create(:goods_nomenclature_description, description:) }

    shared_examples 'a consigned from description' do |description, expected_countries|
      subject(:goods_nomenclature_description) { create(:goods_nomenclature_description, description:) }

      it 'returns the consigned from countries' do
        expect(goods_nomenclature_description.consigned_from).to eq(expected_countries)
      end
    end

    it_behaves_like 'a consigned from description', 'consigned from Vietnam', 'Vietnam'
    it_behaves_like 'a consigned from description', 'consigned from Viet Nam', 'Viet Nam'
    it_behaves_like 'a consigned from description', 'consigned from Taiwan or Malaysia', 'Taiwan or Malaysia'
    it_behaves_like 'a consigned from description', 'consigned from Vietnam, Pakistan or the Philippines', 'Vietnam, Pakistan or the Philippines'
    it_behaves_like 'a consigned from description', 'Originating in or consigned from China:<br>- in quantities below 300 units per month or to be transferred to a party in quantities below 300 units per month; or<br>- to be transferred to another holder of an end-use authorisation or to exempted parties', 'China'
    it_behaves_like 'a consigned from description', 'Consigned from Türkiye', 'Türkiye'
    it_behaves_like 'a consigned from description', 'consigned from or originating in Taiwan', 'Taiwan'
    it_behaves_like 'a consigned from description', 'Consigned from Brazil; consigned from Israel', 'Brazil, Israel'

    context 'when there is no `consigned from` in the description' do
      let(:description) { 'some description' }

      it { expect(goods_nomenclature_description.consigned_from).to be_nil }
    end

    context 'when the description is nil' do
      let(:description) { nil }

      it { expect(goods_nomenclature_description.consigned_from).to be_nil }
    end
  end

  describe '#formatted_description' do
    let(:goods_nomenclature_description) { create(:goods_nomenclature_description, description:) }

    context 'when description contains consigned countries' do
      let(:description) { 'Originating in or consigned from China.' }

      it 'returns the formatted description with capitalized first letter and consigned country names' do
        expect(goods_nomenclature_description.formatted_description).to eq('Originating in or consigned from China.')
      end
    end

    context 'when description contains consigned countries with space' do
      let(:description) { 'Originating in or consigned from United Kingdom.' }

      it 'returns the formatted description with capitalized first letter and consigned country names' do
        expect(goods_nomenclature_description.formatted_description).to eq('Originating in or consigned from United Kingdom.')
      end
    end

    context 'when description does not contain consigned countries' do
      let(:description) { 'This is a description without consigned countries.' }

      it 'returns the formatted description with capitalized first letter' do
        expect(goods_nomenclature_description.formatted_description).to eq('This is a description without consigned countries.')
      end
    end

    context 'when description contains consigned and originating countries' do
      let(:description) { 'Consigned from Japan or originating in China.' }

      it 'returns the formatted description with capitalized first letter and consigned country names' do
        expect(goods_nomenclature_description.formatted_description).to eq('Consigned from Japan or originating in China.')
      end
    end
  end
end
