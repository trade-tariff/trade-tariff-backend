RSpec.describe BulkSearch::HitAncestorFinderService do
  subject(:result) { described_class.new(hit, 6).call }

  context 'when there are ancestor digit hit' do
    let(:hit) do
      Hashie::TariffMash.new(
        "_score": 12.98498,
        "_source": {
          "short_code": '1604209011',
          "goods_nomenclature_item_id": '1604209011',
          "description": 'Of the species Clupea harengus',
          'producline_suffix' => '80',
          "goods_nomenclature_class": 'Commodity',
          'declarable' => true,
          "ancestors": [
            {
              "goods_nomenclature_item_id": '1600000000',
              "producline_suffix": '80',
              "short_code": '16',
              "goods_nomenclature_class": 'Chapter',
              "description": 'PREPARATIONS OF MEAT, OF FISH, OF CRUSTACEANS, MOLLUSCS OR OTHER AQUATIC INVERTEBRATES, OR OF INSECTS',
              "declarable": false,
            },
            {
              "goods_nomenclature_item_id": '1604000000',
              "producline_suffix": '80',
              "short_code": '1604',
              "goods_nomenclature_class": 'Heading',
              "description": 'Prepared or preserved fish; caviar and caviar substitutes prepared from fish eggs',
              "declarable": false,
            },
            {
              "goods_nomenclature_item_id": '1604200000',
              "producline_suffix": '80',
              "short_code": '160420', # <--- ancestor digit hit
              "goods_nomenclature_class": 'Subheading',
              "description": 'Other prepared or preserved fish',
              "declarable": false,
            },
          ],
        },
      )
    end

    it 'returns the matching digit ancestor' do
      expect(result).to eq(
        [
          {
            'goods_nomenclature_item_id' => '1604200000',
            'producline_suffix' => '80',
            'short_code' => '160420',
            'goods_nomenclature_class' => 'Subheading',
            'description' => 'Other prepared or preserved fish',
            'declarable' => false,
          },
          :matching_digit_ancestor,
        ],
      )
    end
  end

  context 'when the hit is the target and it is a declarable heading' do
    let(:hit) do
      Hashie::TariffMash.new(
        "_score": 16.493675,
        "_source": {
          "short_code": '9507',
          "description": 'Fishing rods',
          "goods_nomenclature_item_id": '9507000000',
          'producline_suffix' => '80',
          "goods_nomenclature_class": 'Heading',
          'declarable' => true,
          "ancestors": [
            {
              "goods_nomenclature_item_id": '9500000000',
              "producline_suffix": '80',
              "short_code": '95',
              "goods_nomenclature_class": 'Chapter',
              "description": 'TOYS, GAMES AND SPORTS REQUISITES; PARTS AND ACCESSORIES THEREOF',
              "declarable": false,
            },
          ],
        },
      )
    end

    it 'returns the declarable heading' do
      expect(result).to eq(
        [
          {
            'short_code' => '9507',
            'description' => 'Fishing rods',
            'goods_nomenclature_item_id' => '9507000000',
            'producline_suffix' => '80',
            'goods_nomenclature_class' => 'Heading',
            'declarable' => true,
            'ancestors' => [
              {
                'goods_nomenclature_item_id' => '9500000000',
                'producline_suffix' => '80',
                'short_code' => '95',
                'goods_nomenclature_class' => 'Chapter',
                'description' => 'TOYS, GAMES AND SPORTS REQUISITES; PARTS AND ACCESSORIES THEREOF',
                'declarable' => false,
              },
            ],
          },
          :matching_declarable_heading,
        ],
      )
    end
  end

  context 'when the heading ancestor is the target' do
    let(:hit) do
      Hashie::TariffMash.new(
        "_score": 16.493675,
        "_source": {
          "short_code": '95071010',
          "description": 'Fishing rods',
          "goods_nomenclature_item_id": '9507101000',
          'description' => 'Fish-hooks, whether or not snelled',
          'producline_suffix' => '80',
          "goods_nomenclature_class": 'Commodity',
          'declarable' => true,
          "ancestors": [
            {
              "goods_nomenclature_item_id": '9500000000',
              "producline_suffix": '80',
              "short_code": '95',
              "goods_nomenclature_class": 'Chapter',
              "description": 'TOYS, GAMES AND SPORTS REQUISITES; PARTS AND ACCESSORIES THEREOF',
              "declarable": false,
            },
            {
              "goods_nomenclature_item_id": '9507000000',
              "producline_suffix": '80',
              "short_code": '9507',
              "goods_nomenclature_class": 'Heading',
              "description": "Fishing rods, fish-hooks and other line fishing tackle; fish landing nets, butterfly nets and similar nets; decoy 'birds' (other than those of heading 9208 or 9705) and similar hunting or shooting requisites",
              "declarable": false,
            },
          ],
        },
      )
    end

    it 'returns the heading' do
      expect(result).to eq(
        [
          {
            'goods_nomenclature_item_id' => '9507000000',
            'producline_suffix' => '80',
            'short_code' => '9507',
            'goods_nomenclature_class' => 'Heading',
            'description' => "Fishing rods, fish-hooks and other line fishing tackle; fish landing nets, butterfly nets and similar nets; decoy 'birds' (other than those of heading 9208 or 9705) and similar hunting or shooting requisites",
            'declarable' => false,
          },
          :matching_heading_ancestor,
        ],
      )
    end
  end

  context 'when the hit is the target' do
    let(:hit) do
      Hashie::TariffMash.new(
        "_score": 16.493675,
        "_source": {
          "short_code": '950710', # Has targeted number of digits
          "description": 'Fishing rods',
          "goods_nomenclature_item_id": '9507100000',
          'description' => 'Fish-hooks, whether or not snelled',
          'producline_suffix' => '80',
          "goods_nomenclature_class": 'Commodity',
          'declarable' => true,
          "ancestors": [
            {
              "goods_nomenclature_item_id": '9500000000',
              "producline_suffix": '80',
              "short_code": '95',
              "goods_nomenclature_class": 'Chapter',
              "description": 'TOYS, GAMES AND SPORTS REQUISITES; PARTS AND ACCESSORIES THEREOF',
              "declarable": false,
            },
            {
              "goods_nomenclature_item_id": '9507000000',
              "producline_suffix": '80',
              "short_code": '9507',
              "goods_nomenclature_class": 'Heading',
              "description": "Fishing rods, fish-hooks and other line fishing tackle; fish landing nets, butterfly nets and similar nets; decoy 'birds' (other than those of heading 9208 or 9705) and similar hunting or shooting requisites",
              "declarable": false,
            },
          ],
        },
      )
    end

    it 'returns the hit' do
      expect(result).to eq(
        [
          {
            'short_code' => '950710',
            'description' => 'Fish-hooks, whether or not snelled',
            'goods_nomenclature_item_id' => '9507100000',
            'producline_suffix' => '80',
            'goods_nomenclature_class' => 'Commodity',
            'declarable' => true,
            'ancestors' => [
              { 'goods_nomenclature_item_id' => '9500000000', 'producline_suffix' => '80', 'short_code' => '95', 'goods_nomenclature_class' => 'Chapter', 'description' => 'TOYS, GAMES AND SPORTS REQUISITES; PARTS AND ACCESSORIES THEREOF', 'declarable' => false },
              {
                'goods_nomenclature_item_id' => '9507000000',
                'producline_suffix' => '80',
                'short_code' => '9507',
                'goods_nomenclature_class' => 'Heading',
                'description' => "Fishing rods, fish-hooks and other line fishing tackle; fish landing nets, butterfly nets and similar nets; decoy 'birds' (other than those of heading 9208 or 9705) and similar hunting or shooting requisites",
                'declarable' => false,
              },
            ],
          },
          :matching_digit_commodity,
        ],
      )
    end
  end
end
