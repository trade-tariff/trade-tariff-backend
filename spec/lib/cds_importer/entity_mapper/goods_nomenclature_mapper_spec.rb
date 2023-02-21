RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureMapper do
  let(:xml_node) do
    {
      'hjid' => '607643',
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'T',
        'status' => 'L',
        'transactionDate' => '2023-01-10T17:09:01',
      },
      'sid' => '87045',
      'goodsNomenclatureItemId' => '8112922100',
      'produclineSuffix' => '80',
      'statisticalIndicator' => '0',
      'validityStartDate' => '2007-01-01T00:00:00',
      'footnoteAssociationGoodsNomenclature' => [
        {
          'hjid' => '10681792',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2020-11-28T14:42:15',
          },
          'validityStartDate' => '2021-01-01T00:00:00',
          'footnote' => {
            'hjid' => '10654982',
            'footnoteId' => '204',
            'footnoteType' => {
              'hjid' => '300',
              'footnoteTypeId' => 'TN',
            },
          },
        },
      ],
      'goodsNomenclatureDescriptionPeriod' => [
        {
          'hjid' => '768715',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-18T14:15:03',
          },
          'sid' => '127397',
          'validityStartDate' => '2014-01-01T00:00:00',
          'goodsNomenclatureDescription' => {
            'hjid' => '8666878',
            'metainfo' => {
              'opType' => 'C',
              'origin' => 'T',
              'status' => 'L',
              'transactionDate' => '2018-12-18T14:15:31',
            },
            'description' => 'Waste and scrap',
            'language' => {
              'hjid' => '9',
              'languageId' => 'EN',
            },
          },
        },
      ],
      'goodsNomenclatureIndents' => [
        {
          'hjid' => '671381',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T07:32:00',
          },
          'sid' => '86531',
          'numberIndents' => '04',
          'validityStartDate' => '2007-01-01T00:00:00',
        },
      ],
      'goodsNomenclatureOrigin' => [
        {
          'hjid' => '846308',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T09:01:48',
          },
          'derivedGoodsNomenclatureItemId' => '8112925000',
          'derivedProductlineSuffix' => '80',
        },
        {
          'hjid' => '846307',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T09:01:49',
          },
          'derivedGoodsNomenclatureItemId' => '8112923900',
          'derivedProductlineSuffix' => '80',
        },
        {
          'hjid' => '846305',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T09:01:54',
          },
          'derivedGoodsNomenclatureItemId' => '8112304000',
          'derivedProductlineSuffix' => '80',
        },
        {
          'hjid' => '846306',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T09:01:55',
          },
          'derivedGoodsNomenclatureItemId' => '8112401000',
          'derivedProductlineSuffix' => '80',
        },
      ],
      'filename' => 'tariff_dailyExtract_v1_20230110T235959.gzip',
    }
  end

  it_behaves_like 'an entity mapper', 'GoodsNomenclature', 'GoodsNomenclature' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('2007-01-01'),
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2023-01-10'),
        goods_nomenclature_sid: 87_045,
        goods_nomenclature_item_id: '8112922100',
        producline_suffix: '80',
        statistical_indicator: 0,
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('GoodsNomenclature', xml_node) }

    context 'when there are missing secondary entities to be soft deleted' do
      before do
        # Creates entities that will be missing from the xml node
        create(
          :goods_nomenclature,
          :with_footnote_association,
          :with_indent,
          :with_description,
          goods_nomenclature_sid: '87045',
        )

        # Control for non-deleted secondary entities
        create(:footnote_association_goods_nomenclature, goods_nomenclature_sid: '87045', footnote_type: 'TN', footnote_id: '204')
        create(:goods_nomenclature_indent, goods_nomenclature_sid: '87045', goods_nomenclature_indent_sid: '86531')
        create(:goods_nomenclature_description_period, goods_nomenclature_sid: '87045', goods_nomenclature_description_period_sid: '127397')
      end

      it_behaves_like 'an entity mapper missing destroy operation', FootnoteAssociationGoodsNomenclature, goods_nomenclature_sid: '87045'
      it_behaves_like 'an entity mapper missing destroy operation', GoodsNomenclatureIndent, goods_nomenclature_sid: '87045'
      it_behaves_like 'an entity mapper missing destroy operation', GoodsNomenclatureDescriptionPeriod, goods_nomenclature_sid: '87045'
    end
  end
end
