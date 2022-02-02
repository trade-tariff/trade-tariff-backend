RSpec.describe AnnotatedCommodityService do
  subject(:service) { described_class.new(goods_nomenclature) }

  describe '#call' do
    context 'when a heading is passed' do
      # Live horses, asses, mules and hinnies
      # Horses
      # -- Pure-bred breeding animals
      # -- Other
      # ---- For slaughter
      # ---- Other
      # Asses
      # Other
      let(:goods_nomenclature) do
        path = Rails.root.join(file_fixture_path, 'cached_heading_exhaustive.json')
        file = File.read(path)
        file = JSON.parse(file)

        Hashie::Mash.new(file)
      end

      it 'annotates the commodities with the correct parent sids' do
        expected_sids = [
          nil,    # Horses
          93_797, # -- Pure-bred breeding animals
          93_797, # -- Other
          93_798, # ---- For slaughter
          93_798, # ---- Other
          nil,    # Asses
          nil,    # Other
        ]
        actual_sids = service.call.commodities.map { |commodity| commodity['parent_sid'] }

        expect(actual_sids).to eq(expected_sids)
      end

      it 'annotates the commodities with the correct leaf label' do
        expected_leafs = [
          false, # Horses
          true,  # -- Pure-bred breeding animals
          false, # -- Other
          true,  # ---- For slaughter
          true,  # ---- Other
          true,  # Asses
          true,  # Other
        ]
        actual_leafs = service.call.commodities.map { |commodity| commodity['leaf'] }

        expect(actual_leafs).to eq(expected_leafs)
      end
    end

    context 'when a subheading is passed' do
      # Live horses, asses, mules and hinnies
      # Horses
      # -- Other
      # ---- For slaughter
      # ---- Other
      let(:goods_nomenclature) do
        path = Rails.root.join(file_fixture_path, 'cached_subheading_exhaustive.json')
        file = File.read(path)
        file = JSON.parse(file)

        Hashie::Mash.new(file)
      end

      it 'annotates the commodities with the correct parent sids' do
        expected_sids = [
          nil,    # Horses
          93_797, # -- Other
          93_798, # ---- For slaughter
          93_798, # ---- Other
        ]
        actual_sids = service.call.commodities.map { |commodity| commodity['parent_sid'] }

        expect(actual_sids).to eq(expected_sids)
      end

      it 'annotates the commodities with the correct leaf label' do
        expected_leafs = [
          false, # Horses
          false, # -- Other
          true,  # ---- For slaughter
          true,  # ---- Other
        ]
        actual_leafs = service.call.commodities.map { |commodity| commodity['leaf'] }

        expect(actual_leafs).to eq(expected_leafs)
      end
    end
  end
end
