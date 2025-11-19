require 'spec_helper'

RSpec.describe ClassificationDescriptionHelper do
  let(:dummy_class) do
    Class.new do
      include ClassificationDescriptionHelper

      attr_accessor :formatted_description, :ancestors, :heading
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
end
