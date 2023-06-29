RSpec.describe BulkSearch::ResultAnswerService do
  subject(:service) { described_class.new(search, hits) }

  let(:search) do
    BulkSearch::Search.build(
      input_description: 'red herring',
      ancestor_digits: 8,
      search_result_ancestors: [],
    )
  end

  context 'when nil is passed as the hits' do
    let(:hits) { nil }

    it 'sets the fallback search result ancestor short code' do
      expect { service.call }
        .to change { search.search_result_ancestors.first&.short_code }
        .from(nil)
        .to('999999')
    end
  end

  context 'when there are no hits' do
    let(:hits) { [] }

    it 'sets the fallback search result ancestor short code' do
      expect { service.call }
        .to change { search.search_result_ancestors.first&.short_code }
        .from(nil)
        .to('999999')
    end
  end

  context 'when there are ancestor digit hits' do
    let(:hits) do
      [
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
        ),
      ]
    end

    it 'sets the search result ancestor attributes' do
      service.call

      search_result_ancestor = search.search_result_ancestors.first

      expect(search_result_ancestor).to have_attributes(
        short_code: '160420',
        goods_nomenclature_item_id: '1604200000',
        description: 'Other prepared or preserved fish',
        goods_nomenclature_class: 'Subheading',
        declarable: false,
        reason: :matching_digit_ancestor,
        score: 12.98498,
      )
    end
  end

  context 'when the hit is the target and it is a declarable heading' do
    let(:hits) do
      [
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
        ),
      ]
    end

    it 'sets the search result ancestor attributes' do
      service.call

      search_result_ancestor = search.search_result_ancestors.first

      expect(search_result_ancestor).to have_attributes(
        short_code: '9507',
        goods_nomenclature_item_id: '9507000000',
        description: 'Fishing rods',
        goods_nomenclature_class: 'Heading',
        declarable: true,
        reason: :matching_declarable_heading,
        score: 16.493675,
      )
    end
  end

  context 'when the heading ancestor is the target' do
    let(:hits) do
      [
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
        ),
      ]
    end

    it 'sets the search result ancestor attributes' do
      service.call

      search_result_ancestor = search.search_result_ancestors.first

      expect(search_result_ancestor).to have_attributes(
        short_code: '9507',
        goods_nomenclature_item_id: '9507000000',
        description: "Fishing rods, fish-hooks and other line fishing tackle; fish landing nets, butterfly nets and similar nets; decoy 'birds' (other than those of heading 9208 or 9705) and similar hunting or shooting requisites",
        goods_nomenclature_class: 'Heading',
        declarable: false,
        reason: :matching_heading_ancestor,
        score: 16.493675,
      )
    end
  end

  context 'when the hit is the target' do
    let(:hits) do
      [
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
        ),
      ]
    end

    it 'sets the search result ancestor attributes' do
      service.call

      search_result_ancestor = search.search_result_ancestors.first

      expect(search_result_ancestor).to have_attributes(
        short_code: '950710',
        goods_nomenclature_item_id: '9507100000',
        description: 'Fish-hooks, whether or not snelled',
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        declarable: true,
        reason: :matching_digit_commodity,
        score: 16.493675,
      )
    end
  end
end
