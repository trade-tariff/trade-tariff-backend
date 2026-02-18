require 'spec_helper'

RSpec.describe ClassificationDescription do
  let(:dummy_class) do
    Class.new do
      include ClassificationDescription

      attr_accessor :description, :formatted_description, :ancestors, :heading
    end
  end

  let(:helper) { dummy_class.new }

  describe '#descriptions_with_other_handling' do
    subject(:descriptions) { helper.descriptions_with_other_handling(description) }

    before do
      helper.ancestors = ancestors
      helper.heading = heading
    end

    let(:heading) { instance_double(GoodsNomenclature, formatted_description: 'Heading') }

    context 'when the description is "other" with no ancestors' do
      let(:description) { 'Other' }
      let(:ancestors) { [] }

      it 'returns heading + Other' do
        expect(descriptions).to eq(%w[Heading Other])
      end
    end

    context 'when the description is "other" and there are ancestors' do
      let(:description) { 'Other' }

      let(:ancestor1) { instance_double(GoodsNomenclature, formatted_description: 'Foo') }
      let(:ancestor2) { instance_double(GoodsNomenclature, formatted_description: 'Bar') }

      let(:ancestors) { [ancestor1, ancestor2] }

      it 'returns the chain until the first non-other ancestor' do
        expect(descriptions).to eq(%w[Bar Other])
      end
    end

    context 'when ALL ancestors are "other"' do
      let(:description) { 'Other' }

      let(:ancestor1) { instance_double(GoodsNomenclature, formatted_description: 'Other') }
      let(:ancestor2) { instance_double(GoodsNomenclature, formatted_description: 'Other') }

      let(:ancestors) { [ancestor1, ancestor2] }

      it 'prepends heading as fallback' do
        expect(descriptions).to eq(%w[Heading Other Other Other])
      end
    end
  end

  describe '#raw_classification_description' do
    subject(:raw_desc) { helper.raw_classification_description }

    before do
      helper.description = description
      helper.ancestors = ancestors
      helper.heading = heading
    end

    let(:heading) { instance_double(GoodsNomenclature, description: 'Heading') }

    context 'when description is not "other"' do
      let(:description) { 'Live horses' }
      let(:ancestors) { [] }

      it 'returns the description as-is' do
        expect(raw_desc).to eq('Live horses')
      end
    end

    context 'when description is "other" with a non-other ancestor' do
      let(:description) { 'Other' }
      let(:ancestor1) { instance_double(GoodsNomenclature, description: 'Live horses') }
      let(:ancestors) { [ancestor1] }

      it 'chains ancestor > Other' do
        expect(raw_desc).to eq('Live horses > Other')
      end
    end

    context 'when all ancestors are "other"' do
      let(:description) { 'Other' }
      let(:ancestor1) { instance_double(GoodsNomenclature, description: 'Other') }
      let(:ancestors) { [ancestor1] }

      it 'prepends heading as fallback' do
        expect(raw_desc).to eq('Heading > Other > Other')
      end
    end
  end
end
