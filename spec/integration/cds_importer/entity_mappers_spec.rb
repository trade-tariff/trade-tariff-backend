require_dependency 'cds_importer/entity_mapper/goods_nomenclature_mapper'

RSpec.describe CdsImporter::EntityMapper do
  describe '#process!' do
    before do
      # allow setting primary keys
      Sequel::Model.subclasses.each(&:unrestrict_primary_key)
    end

    it 'AdditionalCode sample' do
      hash_double = double(
        :hash_from_node,
        name: 'AdditionalCode',
        values: {
          'sid' => '3084',
          'additionalCodeCode' => '169',
          'validityEndDate' => '1996-06-14T23:59:59',
          'validityStartDate' => '1991-06-01T00:00:00',
          'additionalCodeType' => {
            'additionalCodeTypeId' => '8',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'U',
            'transactionDate' => '2016-07-27T09:20:15',
          },
        },
      )
      subject = CdsImporter::EntityMapper::AdditionalCodeMapper.new(hash_double.values)
      entity = subject.parse[0]
      expect(entity).to be_a(AdditionalCode)
      expect(entity).to be_valid
      expect(entity.additional_code_sid.to_s).to eq(hash_double.values['sid'])
      expect(entity.additional_code).to eq(hash_double.values['additionalCodeCode'])
      expect(entity.additional_code_type_id).to eq(hash_double.values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.validity_end_date).to eq(hash_double.values['validityEndDate'])
      expect(entity.validity_start_date).to eq(hash_double.values['validityStartDate'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(hash_double.values['metainfo']['transactionDate']))
    end

    it 'AdditionalCodeDescription sample' do
      # NB AdditionalCodeDescription is nested inside AdditionalCode
      #   so following hash is a double from AdditionalCode hash
      hash_double = double(
        :hash_from_node,
        name: 'AdditionalCodeDescription',
        values: {
          'sid' => '3084',
          'additionalCodeCode' => '169',
          'additionalCodeType' => {
            'additionalCodeTypeId' => '8',
          },
          'additionalCodeDescriptionPeriod' => {
            'sid' => '536',
            'additionalCodeDescription' => {
              'description' => 'Other.',
              'language' => {
                'languageId' => 'EN',
              },
              'metainfo' => {
                'origin' => 'T',
                'opType' => 'C',
                'transactionDate' => '2016-07-27T09:20:14',
              },
            },
          },
        },
      )
      # TODO: instruct AdditionalCodeMapper on how to parse
      # children AdditionalCodeDescription
      klass = CdsImporter::EntityMapper::AdditionalCodeDescriptionMapper
      entity = klass.new(hash_double.values).parse[0]
      expect(entity).to be_a(AdditionalCodeDescription)
      expect(entity).to be_valid
      expect(entity.additional_code_description_period_sid.to_s).to eq(hash_double.values['additionalCodeDescriptionPeriod']['sid'])
      expect(entity.language_id).to eq(hash_double.values['additionalCodeDescriptionPeriod']['additionalCodeDescription']['language']['languageId'])
      expect(entity.additional_code_sid.to_s).to eq(hash_double.values['sid'])
      expect(entity.additional_code_type_id).to eq(hash_double.values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.additional_code).to eq(hash_double.values['additionalCodeCode'])
      expect(entity.description).to eq(hash_double.values['additionalCodeDescriptionPeriod']['additionalCodeDescription']['description'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(hash_double.values['additionalCodeDescriptionPeriod']['additionalCodeDescription']['metainfo']['transactionDate']))
    end

    it 'AdditionalCodeDescriptionPeriod sample' do
      hash_double = double(
        :hash_from_node,
        name: 'AdditionalCodeDescriptionPeriod',
        values: {
          'sid' => '3084',
          'additionalCodeCode' => '169',
          'additionalCodeType' => {
            'additionalCodeTypeId' => '8',
          },
          'additionalCodeDescriptionPeriod' => {
            'sid' => '536',
            'validityStartDate' => '1991-06-01T00:00:00',
            'validityEndDate' => '1992-06-01T00:00:00',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2016-07-27T09:20:15',
            },
          },
        },
      )
      klass = CdsImporter::EntityMapper::AdditionalCodeDescriptionPeriodMapper
      entity = klass.new(hash_double.values).parse[0]
      expect(entity).to be_a(AdditionalCodeDescriptionPeriod)
      expect(entity).to be_valid
      expect(entity.additional_code_description_period_sid.to_s).to eq(hash_double.values['additionalCodeDescriptionPeriod']['sid'])
      expect(entity.additional_code_sid.to_s).to eq(hash_double.values['sid'])
      expect(entity.additional_code_type_id).to eq(hash_double.values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.additional_code).to eq(hash_double.values['additionalCodeCode'])
      expect(entity.validity_start_date).to eq(hash_double.values['additionalCodeDescriptionPeriod']['validityStartDate'])
      expect(entity.validity_end_date).to eq(hash_double.values['additionalCodeDescriptionPeriod']['validityEndDate'])
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(hash_double.values['additionalCodeDescriptionPeriod']['metainfo']['transactionDate']))
    end

    it 'GoodsNomenclature sample' do
      values = {
        'sid' => '1234',
        'goodsNomenclatureItemId' => '9950000000',
        'produclineSuffix' => '80',
        'statisticalIndicator' => '2',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-27T07:26:25',
        },
      }
      subject = CdsImporter::EntityMapper::GoodsNomenclatureMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(GoodsNomenclature)
      expect(entity).to be_valid
      expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
      expect(entity.producline_suffix).to eq(values['produclineSuffix'])
      expect(entity.statistical_indicator.to_s).to eq(values['statisticalIndicator'])
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'GoodsNomenclatureDescription sample' do
      values = {
        'sid' => '1234',
        'goodsNomenclatureItemId' => '9950000000',
        'produclineSuffix' => '80',
        'statisticalIndicator' => '2',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'goodsNomenclatureDescriptionPeriod' => {
          'sid' => '1155',
          'goodsNomenclatureDescription' => {
            'description' => 'Some description.',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-08-24T04:21:16',
            },
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-28T09:23:15',
        },
      }
      subject = CdsImporter::EntityMapper::GoodsNomenclatureDescriptionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(GoodsNomenclatureDescription)
      expect(entity).to be_valid
      expect(entity.goods_nomenclature_description_period_sid.to_s).to eq(values['goodsNomenclatureDescriptionPeriod']['sid'])
      expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
      expect(entity.productline_suffix).to eq(values['produclineSuffix'])
      expect(entity.description).to eq(values['goodsNomenclatureDescriptionPeriod']['goodsNomenclatureDescription']['description'])
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureDescriptionPeriod']['goodsNomenclatureDescription']['metainfo']['transactionDate']))
    end

    it 'CompleteAbrogationRegulation sample' do
      values = {
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'completeAbrogationRegulationId' => 'R9808461',
        'publishedDate' => '2017-08-27T10:11:12',
        'officialjournalNumber' => 'L 120',
        'officialjournalPage' => '13',
        'replacementIndicator' => '0',
        'informationText' => 'TR',
        'approvedFlag' => '0',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-22T17:26:25',
        },
      }
      subject = CdsImporter::EntityMapper::CompleteAbrogationRegulationMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(CompleteAbrogationRegulation)
      expect(entity).to be_valid
      expect(entity.complete_abrogation_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
      expect(entity.complete_abrogation_regulation_id).to eq(values['completeAbrogationRegulationId'])
      expect(entity.published_date).to eq(Date.parse(values['publishedDate']))
      expect(entity.officialjournal_number).to eq(values['officialjournalNumber'])
      expect(entity.officialjournal_page.to_s).to eq(values['officialjournalPage'])
      expect(entity.replacement_indicator.to_s).to eq(values['replacementIndicator'])
      expect(entity.information_text).to eq(values['informationText'])
      expect(entity.approved_flag).to eq(false)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'AdditionalCodeType sample' do
      values = {
        'applicationCode' => '1',
        'additionalCodeTypeId' => '3',
        'validityStartDate' => '1970-01-01T00:00:00',
        'meursingTablePlan' => {
          'meursingTablePlanId' => '01',
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
      subject = CdsImporter::EntityMapper::AdditionalCodeTypeMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(AdditionalCodeType)
      expect(entity).to be_valid
      expect(entity.additional_code_type_id).to eq(values['additionalCodeTypeId'])
      expect(entity.validity_start_date).to eq(values['validityStartDate'])
      expect(entity.application_code).to eq(values['applicationCode'])
      expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlan']['meursingTablePlanId'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'AdditionalCodeTypeDescription sample' do
      values = {
        'additionalCodeTypeId' => '3',
        'additionalCodeTypeDescription' => {
          'description' => 'Prohibition/Restriction/Surveillance',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'C',
            'transactionDate' => '2016-07-27T09:18:51',
          },
        },
      }
      subject = CdsImporter::EntityMapper::AdditionalCodeTypeDescriptionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(AdditionalCodeTypeDescription)
      expect(entity).to be_valid
      expect(entity.additional_code_type_id).to eq(values['additionalCodeTypeId'])
      expect(entity.language_id).to eq(values['additionalCodeTypeDescription']['language']['languageId'])
      expect(entity.description).to eq(values['additionalCodeTypeDescription']['description'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['additionalCodeTypeDescription']['metainfo']['transactionDate']))
    end

    it 'AdditionalCodeTypeMeasureType sample' do
      values = {
        'additionalCodeTypeId' => '3',
        'additionalCodeTypeMeasureType' => {
          'validityStartDate' => '1999-09-01T00:00:00',
          'measureType' => {
            'measureTypeId' => '468',
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'N',
            'transactionDate' => '2016-07-22T20:03:35',
          },
        },
      }
      subject = CdsImporter::EntityMapper::AdditionalCodeTypeMeasureTypeMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(AdditionalCodeTypeMeasureType)
      expect(entity).to be_valid
      expect(entity.measure_type_id).to eq(values['additionalCodeTypeMeasureType']['measureType']['measureTypeId'])
      expect(entity.additional_code_type_id).to eq(values['additionalCodeTypeId'])
      expect(entity.validity_start_date).to eq(values['additionalCodeTypeMeasureType']['validityStartDate'])
      expect(entity.operation).to eq(:create)
      expect(entity.national).to be_truthy
      expect(entity.operation_date).to eq(Date.parse(values['additionalCodeTypeMeasureType']['metainfo']['transactionDate']))
    end

    it 'DutyExpressionDescription sample' do
      values = {
        'sid' => 123_456,
        'dutyExpressionId' => '1234',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'dutyExpressionDescription' => {
          'description' => 'Some description',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'C',
            'transactionDate' => '2016-07-27T09:20:14',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-09-27T07:26:25',
        },
      }
      subject = CdsImporter::EntityMapper::DutyExpressionDescriptionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(DutyExpressionDescription)
      expect(entity).to be_valid
      expect(entity.duty_expression_id).to eq(values['dutyExpressionId'])
      expect(entity.language_id).to eq(values['dutyExpressionDescription']['language']['languageId'])
      expect(entity.description).to eq(values['dutyExpressionDescription']['description'])
      expect(entity.operation_date).to eq(Date.parse(values['dutyExpressionDescription']['metainfo']['transactionDate']))
      expect(entity.operation).to eq(:create)
    end

    it 'CompleteAbrogationRegulation sample' do
      values = {
        'regulationRoleType' => {
          'sid' => '4321',
          'regulationRoleTypeId' => '7',
        },
        'completeAbrogationRegulationId' => 'R9808461',
        'publishedDate' => '2017-08-27T10:11:12',
        'officialjournalNumber' => 'L 120',
        'officialjournalPage' => '13',
        'replacementIndicator' => '0',
        'abrogationDate' => '2017-09-21T10:07:31',
        'informationText' => 'TR',
        'approvedFlag' => '1',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-22T17:26:25',
        },
      }
      subject = CdsImporter::EntityMapper::ExplicitAbrogationRegulationMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(ExplicitAbrogationRegulation)
      expect(entity).to be_valid
      expect(entity.explicit_abrogation_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
      expect(entity.explicit_abrogation_regulation_id).to eq(values['explicitAbrogationRegulationId'])
      expect(entity.published_date).to eq(Date.parse(values['publishedDate']))
      expect(entity.officialjournal_number).to eq(values['officialjournalNumber'])
      expect(entity.officialjournal_page.to_s).to eq(values['officialjournalPage'])
      expect(entity.replacement_indicator.to_s).to eq(values['replacementIndicator'])
      expect(entity.abrogation_date).to eq(Date.parse(values['abrogationDate']))
      expect(entity.information_text).to eq(values['informationText'])
      expect(entity.approved_flag).to eq(true)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'ExportRefundNomenclature sample' do
      values = {
        'sid' => '1233',
        'exportRefundCode' => '700',
        'productLine' => '80',
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'goodsNomenclature' => {
          'sid' => '1234',
          'goodsNomenclatureItemId' => '9950000000',
          'produclineSuffix' => '80',
          'statisticalIndicator' => '2',
          'validityStartDate' => '2017-10-01T00:00:00',
          'validityEndDate' => '2020-09-01T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-09-27T07:26:25',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-08-21T17:21:35',
        },
      }
      subject = CdsImporter::EntityMapper::ExportRefundNomenclatureMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(ExportRefundNomenclature)
      expect(entity).to be_valid
      expect(entity.export_refund_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
      expect(entity.goods_nomenclature_sid.to_s).to eq(values['goodsNomenclature']['sid'])
      expect(entity.additional_code_type).to eq(values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.export_refund_code).to eq(values['exportRefundCode'])
      expect(entity.productline_suffix).to eq(values['productLine'])
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
      expect(entity.operation).to eq(:update)
    end

    it 'ExportRefundNomenclatureIndent sample' do
      values = {
        'sid' => '1233',
        'exportRefundCode' => '700',
        'productLine' => '80',
        'exportRefundNomenclatureIndents' => {
          'sid' => '3322',
          'numberExportRefundNomenclatureIndents' => 2,
          'validityStartDate' => '2015-06-11T00:00:00',
          'validityEndDate' => '2020-04-03T00:00:00',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-07-22T15:22:15',
          },
        },
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'goodsNomenclature' => {
          'sid' => '1234',
          'goodsNomenclatureItemId' => '9950000000',
          'produclineSuffix' => '80',
          'statisticalIndicator' => '2',
          'validityStartDate' => '2017-10-01T00:00:00',
          'validityEndDate' => '2020-09-01T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-09-27T07:26:25',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-08-21T17:21:35',
        },
      }
      subject = CdsImporter::EntityMapper::ExportRefundNomenclatureIndentMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(ExportRefundNomenclatureIndent)
      expect(entity).to be_valid
      expect(entity.export_refund_nomenclature_indents_sid.to_s).to eq(values['exportRefundNomenclatureIndents']['sid'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
      expect(entity.number_export_refund_nomenclature_indents).to eq(values['exportRefundNomenclatureIndents']['numberExportRefundNomenclatureIndents'])
      expect(entity.additional_code_type).to eq(values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.export_refund_code).to eq(values['exportRefundCode'])
      expect(entity.productline_suffix).to eq(values['productLine'])
      expect(entity.operation_date).to eq(Date.parse(values['exportRefundNomenclatureIndents']['metainfo']['transactionDate']))
      expect(entity.operation).to eq(:create)
      expect(entity.validity_start_date).to eq(Date.parse(values['exportRefundNomenclatureIndents']['validityStartDate']))
      expect(entity.validity_end_date).to eq(Date.parse(values['exportRefundNomenclatureIndents']['validityEndDate']))
    end

    it 'ExportRefundNomenclatureDescriptionPeriod sample' do
      values = {
        'sid' => '1233',
        'exportRefundCode' => '700',
        'productLine' => '80',
        'exportRefundNomenclatureDescriptionPeriod' => {
          'sid' => '1126',
          'validityStartDate' => '2014-06-12T00:00:00',
          'validityEndDate' => '2019-05-02T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-22T15:22:15',
          },
        },
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'goodsNomenclature' => {
          'sid' => '1234',
          'goodsNomenclatureItemId' => '9950000000',
          'produclineSuffix' => '80',
          'statisticalIndicator' => '2',
          'validityStartDate' => '2017-10-01T00:00:00',
          'validityEndDate' => '2020-09-01T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-09-27T07:26:25',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-08-21T17:21:35',
        },
      }
      subject = CdsImporter::EntityMapper::ExportRefundNomenclatureDescriptionPeriodMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(ExportRefundNomenclatureDescriptionPeriod)
      expect(entity).to be_valid
      expect(entity.export_refund_nomenclature_description_period_sid.to_s).to eq(values['exportRefundNomenclatureDescriptionPeriod']['sid'])
      expect(entity.export_refund_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
      expect(entity.additional_code_type).to eq(values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.export_refund_code).to eq(values['exportRefundCode'])
      expect(entity.productline_suffix).to eq(values['productLine'])
      expect(entity.operation_date).to eq(Date.parse(values['exportRefundNomenclatureDescriptionPeriod']['metainfo']['transactionDate']))
      expect(entity.operation).to eq(:update)
      expect(entity.validity_start_date).to eq(Date.parse(values['exportRefundNomenclatureDescriptionPeriod']['validityStartDate']))
      expect(entity.validity_end_date).to eq(Date.parse(values['exportRefundNomenclatureDescriptionPeriod']['validityEndDate']))
    end

    it 'ExportRefundNomenclatureDescriptionPeriod sample' do
      values = {
        'sid' => '1114',
        'exportRefundCode' => '700',
        'productLine' => '80',
        'exportRefundNomenclatureDescriptionPeriod' => {
          'sid' => '4211',
          'validityStartDate' => '2015-06-17T00:00:00',
          'validityEndDate' => '2019-06-02T00:00:00',
          'exportRefundNomenclatureDescription' => {
            'description' => 'Some description',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'opType' => 'C',
              'transactionDate' => '2017-09-25T10:21:15',
            },
          },
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-22T15:22:15',
          },
        },
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'goodsNomenclature' => {
          'sid' => '1234',
          'goodsNomenclatureItemId' => '9950000000',
          'produclineSuffix' => '80',
          'statisticalIndicator' => '2',
          'validityStartDate' => '2017-10-01T00:00:00',
          'validityEndDate' => '2020-09-01T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-09-27T07:26:25',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-08-21T17:21:35',
        },
      }
      subject = CdsImporter::EntityMapper::ExportRefundNomenclatureDescriptionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(ExportRefundNomenclatureDescription)
      expect(entity).to be_valid
      expect(entity.export_refund_nomenclature_description_period_sid.to_s).to eq(values['exportRefundNomenclatureDescriptionPeriod']['sid'])
      expect(entity.export_refund_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.language_id).to eq(values['exportRefundNomenclatureDescriptionPeriod']['exportRefundNomenclatureDescription']['language']['languageId'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
      expect(entity.additional_code_type).to eq(values['additionalCodeType']['additionalCodeTypeId'])
      expect(entity.export_refund_code).to eq(values['exportRefundCode'])
      expect(entity.productline_suffix).to eq(values['productLine'])
      expect(entity.operation_date).to eq(Date.parse(values['exportRefundNomenclatureDescriptionPeriod']['exportRefundNomenclatureDescription']['metainfo']['transactionDate']))
      expect(entity.operation).to eq(:create)
    end

    it 'DutyExpression sample' do
      values = {
        'dutyExpressionId' => '14',
        'validityEndDate' => '1995-06-30T23:59:59',
        'validityStartDate' => '1972-01-01T00:00:00',
        'dutyAmountApplicabilityCode' => '2',
        'measurementUnitApplicabilityCode' => '0',
        'monetaryUnitApplicabilityCode' => '0',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:10',
        },
      }
      subject = CdsImporter::EntityMapper::DutyExpressionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(DutyExpression)
      expect(entity).to be_valid
      expect(entity.duty_expression_id).to eq(values['dutyExpressionId'])
      expect(entity.validity_end_date).to eq(values['validityEndDate'])
      expect(entity.validity_start_date).to eq(values['validityStartDate'])
      expect(entity.duty_amount_applicability_code.to_s).to eq(values['dutyAmountApplicabilityCode'])
      expect(entity.measurement_unit_applicability_code.to_s).to eq(values['measurementUnitApplicabilityCode'])
      expect(entity.monetary_unit_applicability_code.to_s).to eq(values['monetaryUnitApplicabilityCode'])
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'Footnote sample' do
      values = {
        'footnoteId' => '133',
        'validityStartDate' => '1972-01-01T00:00:00',
        'validityEndDate' => '1973-01-01T00:00:00',
        'footnoteType' => {
          'footnoteTypeId' => 'TM',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:57',
        },
      }
      subject = CdsImporter::EntityMapper::FootnoteMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(Footnote)
      expect(entity).to be_valid
      expect(entity.footnote_id).to eq(values['footnoteId'])
      expect(entity.footnote_type_id).to eq(values['footnoteType']['footnoteTypeId'])
      expect(entity.validity_start_date).to eq(values['validityStartDate'])
      expect(entity.validity_end_date).to eq(values['validityEndDate'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'FootnoteAssociationGoodsNomenclature sample' do
      values = {
        'sid' => '27652',
        'produclineSuffix' => '80',
        'goodsNomenclatureItemId' => '0102903131',
        'footnoteAssociationGoodsNomenclature' => {
          'validityEndDate' => '1992-12-31T23:59:59',
          'validityStartDate' => '1991-01-01T00:00:00',
          'footnote' => {
            'footnoteId' => '001',
            'footnoteType' => {
              'footnoteTypeId' => '5',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'transactionDate' => '2016-07-25T11:07:56',
          },
        },
      }
      subject = CdsImporter::EntityMapper::FootnoteAssociationGoodsNomenclatureMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FootnoteAssociationGoodsNomenclature)
      expect(entity).to be_valid
      expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
      expect(entity.footnote_id).to eq(values['footnoteAssociationGoodsNomenclature']['footnote']['footnoteId'])
      expect(entity.footnote_type).to eq(values['footnoteAssociationGoodsNomenclature']['footnote']['footnoteType']['footnoteTypeId'])
      expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
      expect(entity.productline_suffix).to eq(values['produclineSuffix'])
      expect(entity.validity_start_date).to eq(values['footnoteAssociationGoodsNomenclature']['validityStartDate'])
      expect(entity.validity_end_date).to eq(values['footnoteAssociationGoodsNomenclature']['validityEndDate'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['footnoteAssociationGoodsNomenclature']['metainfo']['transactionDate']))
    end

    it 'FootnoteDescription sample' do
      values = {
        'footnoteId' => '133',
        'footnoteType' => {
          'footnoteTypeId' => 'TM',
        },
        'footnoteDescriptionPeriod' => {
          'sid' => '1355',
          'footnoteDescription' => {
            'description' => 'The rate of duty is applicable to the net free-at-Community',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'origin' => 'T',
              'opType' => 'C',
              'transactionDate' => '2016-07-27T09:18:57',
            },
          },
        },
      }
      subject = CdsImporter::EntityMapper::FootnoteDescriptionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FootnoteDescription)
      expect(entity).to be_valid
      expect(entity.footnote_description_period_sid.to_s).to eq(values['footnoteDescriptionPeriod']['sid'])
      expect(entity.footnote_type_id).to eq(values['footnoteType']['footnoteTypeId'])
      expect(entity.footnote_id).to eq(values['footnoteId'])
      expect(entity.language_id).to eq(values['footnoteDescriptionPeriod']['footnoteDescription']['language']['languageId'])
      expect(entity.description).to eq(values['footnoteDescriptionPeriod']['footnoteDescription']['description'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['footnoteDescriptionPeriod']['footnoteDescription']['metainfo']['transactionDate']))
    end

    it 'FootnoteDescriptionPeriod sample' do
      values = {
        'footnoteId' => '123',
        'footnoteType' => {
          'footnoteTypeId' => 'TM',
        },
        'footnoteDescriptionPeriod' => {
          'sid' => '1355',
          'validityStartDate' => '1972-01-01T00:00:00',
          'validityEndDate' => '1973-01-01T00:00:00',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'transactionDate' => '2016-07-27T09:18:57',
          },
        },
      }
      subject = CdsImporter::EntityMapper::FootnoteDescriptionPeriodMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FootnoteDescriptionPeriod)
      expect(entity).to be_valid
      expect(entity.footnote_description_period_sid.to_s).to eq(values['footnoteDescriptionPeriod']['sid'])
      expect(entity.footnote_type_id).to eq(values['footnoteType']['footnoteTypeId'])
      expect(entity.footnote_id).to eq(values['footnoteId'])
      expect(entity.validity_start_date).to eq(values['footnoteDescriptionPeriod']['validityStartDate'])
      expect(entity.validity_end_date).to eq(values['footnoteDescriptionPeriod']['validityEndDate'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['footnoteDescriptionPeriod']['metainfo']['transactionDate']))
    end

    it 'FootnoteType sample' do
      values = {
        'footnoteTypeId' => 'TN',
        'applicationCode' => '2',
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
      subject = CdsImporter::EntityMapper::FootnoteTypeMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FootnoteType)
      expect(entity).to be_valid
      expect(entity.footnote_type_id).to eq(values['footnoteTypeId'])
      expect(entity.application_code.to_s).to eq(values['applicationCode'])
      expect(entity.validity_start_date).to eq(values['validityStartDate'])
      expect(entity.validity_end_date).to eq(values['validityEndDate'])
      expect(entity.national).to be_falsey
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end

    it 'FtsRegulationAction sample' do
      values = {
        'sid' => '1277',
        'approvedFlag' => '1',
        'fullTemporaryStopRegulationId' => '11122',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'ftsRegulationAction' => {
          'sid' => '1127',
          'stoppedRegulationId' => '112233',
          'stoppedRegulationRole' => '5',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-27T19:18:31',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
      subject = CdsImporter::EntityMapper::FtsRegulationActionMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FtsRegulationAction)
      expect(entity).to be_valid
      expect(entity.fts_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
      expect(entity.fts_regulation_id).to eq(values['fullTemporaryStopRegulationId'])
      expect(entity.stopped_regulation_role.to_s).to eq(values['ftsRegulationAction']['stoppedRegulationRole'])
      expect(entity.stopped_regulation_id).to eq(values['ftsRegulationAction']['stoppedRegulationId'])
      expect(entity.operation).to eq(:update)
      expect(entity.operation_date).to eq(Date.parse(values['ftsRegulationAction']['metainfo']['transactionDate']))
    end

    it 'FullTemporaryStopRegulation sample' do
      values = {
        'sid' => '1277',
        'approvedFlag' => '1',
        'fullTemporaryStopRegulationId' => '22113',
        'publishedDate' => '2017-08-25T07:41:22',
        'effectiveEndDate' => '2018-08-20T09:42:12',
        'officialjournalNumber' => 'K 320',
        'officialjournalPage' => '12',
        'replacementIndicator' => '2',
        'informationText' => 'ER',
        'explicitAbrogationRegulation' => {
          'explicitAbrogationRegulationId' => '11226',
          'regulationRoleType' => {
            'regulationRoleTypeId' => '7',
          },
        },
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'ftsRegulationAction' => {
          'sid' => '1127',
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
      subject = CdsImporter::EntityMapper::FullTemporaryStopRegulationMapper.new(values)
      entity = subject.parse[0]
      expect(entity).to be_a(FullTemporaryStopRegulation)
      expect(entity).to be_valid
      expect(entity.full_temporary_stop_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
      expect(entity.full_temporary_stop_regulation_id).to eq(values['fullTemporaryStopRegulationId'])
      expect(entity.explicit_abrogation_regulation_role.to_s).to eq(values['explicitAbrogationRegulation']['regulationRoleType']['regulationRoleTypeId'])
      expect(entity.explicit_abrogation_regulation_id).to eq(values['explicitAbrogationRegulation']['explicitAbrogationRegulationId'])
      expect(entity.published_date).to eq(Date.parse(values['publishedDate']))
      expect(entity.effective_enddate).to eq(Date.parse(values['effectiveEndDate']))
      expect(entity.officialjournal_number).to eq(values['officialjournalNumber'])
      expect(entity.officialjournal_page.to_s).to eq(values['officialjournalPage'])
      expect(entity.replacement_indicator.to_s).to eq(values['replacementIndicator'])
      expect(entity.information_text).to eq(values['informationText'])
      expect(entity.approved_flag).to eq(true)
      expect(entity.operation).to eq(:create)
      expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
    end
  end

  it 'FootnoteAssociationAdditionalCode sample' do
    values = {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'footnoteAssociationAdditionalCode' => {
        'footnote' => {
          'footnoteId' => '08',
          'footnoteType' => {
            'footnoteTypeId' => '06',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-08-27T19:23:57',
        },
      },
      'metainfo' => {
        'origin' => 'T',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
    }
    subject = CdsImporter::EntityMapper::FootnoteAssociationAdditionalCodeMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(FootnoteAssociationAdditionalCode)
    expect(entity).to be_valid
    expect(entity.additional_code_sid.to_s).to eq(values['sid'])
    expect(entity.additional_code_type_id).to eq(values['additionalCodeType']['additionalCodeTypeId'])
    expect(entity.additional_code).to eq(values['additionalCodeCode'])
    expect(entity.footnote_type_id).to eq(values['footnoteAssociationAdditionalCode']['footnote']['footnoteType']['footnoteTypeId'])
    expect(entity.footnote_id).to eq(values['footnoteAssociationAdditionalCode']['footnote']['footnoteId'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['footnoteAssociationAdditionalCode']['metainfo']['transactionDate']))
  end

  it 'FootnoteAssociationMeasure sample' do
    values = {
      'sid' => '3084',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'footnoteAssociationMeasure' => {
        'footnote' => {
          'footnoteId' => '08',
          'footnoteType' => {
            'footnoteTypeId' => '06',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'N',
          'transactionDate' => '2017-08-27T19:23:57',
        },
      },
      'metainfo' => {
        'origin' => 'T',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
    }
    subject = CdsImporter::EntityMapper::FootnoteAssociationMeasureMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(FootnoteAssociationMeasure)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.footnote_type_id).to eq(values['footnoteAssociationMeasure']['footnote']['footnoteType']['footnoteTypeId'])
    expect(entity.footnote_id).to eq(values['footnoteAssociationMeasure']['footnote']['footnoteId'])
    expect(entity.national).to eq(true)
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['footnoteAssociationMeasure']['metainfo']['transactionDate']))
  end

  it 'FootnoteAssociationErn sample' do
    values = {
      'sid' => '3084',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'footnoteAssociationErn' => {
        'validityEndDate' => '1995-07-10T20:59:59',
        'validityStartDate' => '2018-06-03T00:00:00',
        'footnote' => {
          'footnoteId' => '08',
          'footnoteType' => {
            'footnoteTypeId' => '06',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-08-27T19:23:57',
        },
      },
      'goodsNomenclature' => {
        'goodsNomenclatureItemId' => '0102901019',
      },
      'additionalCodeType' => {
        'additionalCodeTypeId' => '06',
      },
      'metainfo' => {
        'origin' => 'T',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
    }
    subject = CdsImporter::EntityMapper::FootnoteAssociationErnMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(FootnoteAssociationErn)
    expect(entity).to be_valid
    expect(entity.export_refund_nomenclature_sid.to_s).to eq(values['sid'])
    expect(entity.footnote_type).to eq(values['footnoteAssociationErn']['footnote']['footnoteType']['footnoteTypeId'])
    expect(entity.footnote_id).to eq(values['footnoteAssociationErn']['footnote']['footnoteId'])
    expect(entity.validity_start_date).to eq(values['footnoteAssociationErn']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['footnoteAssociationErn']['validityEndDate'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
    expect(entity.additional_code_type).to eq(values['additionalCodeType']['additionalCodeTypeId'])
    expect(entity.export_refund_code).to eq(values['exportRefundCode'])
    expect(entity.productline_suffix).to eq(values['productLine'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['footnoteAssociationErn']['metainfo']['transactionDate']))
  end

  it 'FootnoteAssociationMeursingHeading sample' do
    values = {
      'meursingTablePlanId' => '2',
      'meursingHeading' => {
        'sid' => '3084',
        'meursingHeadingNumber' => '6',
        'rowColumnCode' => '1',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'footnoteAssociationMeursingHeading' => {
          'validityEndDate' => '1995-07-10T20:59:59',
          'validityStartDate' => '2018-06-03T00:00:00',
          'footnote' => {
            'footnoteId' => '08',
            'footnoteType' => {
              'footnoteTypeId' => '06',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-08-27T19:23:57',
          },
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      },
    }
    subject = CdsImporter::EntityMapper::FootnoteAssociationMeursingHeadingMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(FootnoteAssociationMeursingHeading)
    expect(entity).to be_valid
    expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlanId'])
    expect(entity.meursing_heading_number).to eq(values['meursingHeading']['meursingHeadingNumber'])
    expect(entity.row_column_code.to_s).to eq(values['meursingHeading']['rowColumnCode'])
    expect(entity.footnote_type).to eq(values['meursingHeading']['footnoteAssociationMeursingHeading']['footnote']['footnoteType']['footnoteTypeId'])
    expect(entity.footnote_id).to eq(values['meursingHeading']['footnoteAssociationMeursingHeading']['footnote']['footnoteId'])
    expect(entity.validity_start_date).to eq(values['meursingHeading']['footnoteAssociationMeursingHeading']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['meursingHeading']['footnoteAssociationMeursingHeading']['validityEndDate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['meursingHeading']['footnoteAssociationMeursingHeading']['metainfo']['transactionDate']))
  end

  it 'FootnoteTypeDescription sample' do
    values = {
      'footnoteTypeId' => 'TN',
      'footnoteTypeDescription' => {
        'description' => 'Taric Nomenclature',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      },
    }
    subject = CdsImporter::EntityMapper::FootnoteTypeDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(FootnoteTypeDescription)
    expect(entity).to be_valid
    expect(entity.footnote_type_id).to eq(values['footnoteTypeId'])
    expect(entity.language_id).to eq(values['footnoteTypeDescription']['language']['languageId'])
    expect(entity.description).to eq(values['footnoteTypeDescription']['description'])
    expect(entity.national).to be_falsey
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['footnoteTypeDescription']['metainfo']['transactionDate']))
  end

  it 'GeographicalArea sample' do
    values = {
      'sid' => '234',
      'validityStartDate' => '1984-01-01T00:00:00',
      'validityEndDate' => nil,
      'geographicalCode' => '1',
      'geographicalAreaId' => '1032',
      'parentGeographicalAreaGroupSid' => '400',
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::GeographicalAreaMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GeographicalArea)
    expect(entity).to be_valid
    expect(entity.geographical_area_sid.to_s).to eq(values['sid'])
    expect(entity.geographical_code).to eq(values['geographicalCode'])
    expect(entity.geographical_area_id).to eq(values['geographicalAreaId'])
    expect(entity.parent_geographical_area_group_sid.to_s).to eq(values['parentGeographicalAreaGroupSid'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'GeographicalAreaDescription sample' do
    values = {
      'sid' => '234',
      'geographicalAreaId' => '1032',
      'geographicalAreaDescriptionPeriod' => {
        'sid' => '1239',
        'geographicalAreaDescription' => {
          'description' => 'Economic Partnership Agreements',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2016-07-27T09:21:40',
          },
        },
      },
    }
    subject = CdsImporter::EntityMapper::GeographicalAreaDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GeographicalAreaDescription)
    expect(entity).to be_valid
    expect(entity.geographical_area_description_period_sid.to_s).to eq(values['geographicalAreaDescriptionPeriod']['sid'])
    expect(entity.language_id).to eq(values['geographicalAreaDescriptionPeriod']['geographicalAreaDescription']['language']['languageId'])
    expect(entity.geographical_area_sid.to_s).to eq(values['sid'])
    expect(entity.geographical_area_id).to eq(values['geographicalAreaId'])
    expect(entity.description).to eq(values['geographicalAreaDescriptionPeriod']['geographicalAreaDescription']['description'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['geographicalAreaDescriptionPeriod']['geographicalAreaDescription']['metainfo']['transactionDate']))
  end

  it 'GeographicalAreaDescriptionPeriod sample' do
    values = {
      'sid' => '234',
      'geographicalAreaId' => '1032',
      'geographicalAreaDescriptionPeriod' => {
        'sid' => '1239',
        'validityStartDate' => '2008-01-01T00:00:00',
        'validityEndDate' => nil,
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GeographicalAreaDescriptionPeriodMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GeographicalAreaDescriptionPeriod)
    expect(entity).to be_valid
    expect(entity.geographical_area_description_period_sid.to_s).to eq(values['geographicalAreaDescriptionPeriod']['sid'])
    expect(entity.geographical_area_sid.to_s).to eq(values['sid'])
    expect(entity.validity_start_date).to eq(values['geographicalAreaDescriptionPeriod']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['geographicalAreaDescriptionPeriod']['validityEndDate'])
    expect(entity.geographical_area_id).to eq(values['geographicalAreaId'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['geographicalAreaDescriptionPeriod']['metainfo']['transactionDate']))
  end

  it 'GeographicalAreaMembership sample' do
    values = {
      'hjid' => '123',
      'sid' => '234',
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-08-29T20:14:17',
      },
      'geographicalAreaMembership' => {
        'hjid' => '25864',
        'geographicalAreaGroupSid' => '461273',
        'geographicalAreaSid' => '311',
        'validityStartDate' => '2008-01-01T00:00:00',
        'validityEndDate' => '2020-06-29T20:04:37',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GeographicalAreaMembershipMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GeographicalAreaMembership)
    expect(entity).to be_valid
    expect(entity.geographical_area_sid.to_s).to eq(values['geographicalAreaMembership']['geographicalAreaSid'])
    expect(entity.geographical_area_group_sid.to_s).to eq(values['geographicalAreaMembership']['geographicalAreaGroupSid'])
    expect(entity.validity_start_date).to eq(values['geographicalAreaMembership']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['geographicalAreaMembership']['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.national).to be_truthy
    expect(entity.operation_date).to eq(Date.parse(values['geographicalAreaMembership']['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureGroup sample' do
    values = {
      'goodsNomenclatureGroupId' => '125000',
      'goodsNomenclatureGroupType' => 'T',
      'nomenclatureGroupFacilityCode' => '123',
      'validityEndDate' => '2019-12-31T23:59:59',
      'validityStartDate' => '1991-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureGroupMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureGroup)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_group_type).to eq(values['goodsNomenclatureGroupType'])
    expect(entity.goods_nomenclature_group_id).to eq(values['goodsNomenclatureGroupId'])
    expect(entity.nomenclature_group_facility_code.to_s).to eq(values['nomenclatureGroupFacilityCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureGroupDescription sample' do
    values = {
      'goodsNomenclatureGroupId' => '125000',
      'goodsNomenclatureGroupType' => 'T',
      'goodsNomenclatureGroupDescription' => {
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureGroupDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureGroupDescription)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_group_type).to eq(values['goodsNomenclatureGroupType'])
    expect(entity.goods_nomenclature_group_id).to eq(values['goodsNomenclatureGroupId'])
    expect(entity.language_id).to eq(values['goodsNomenclatureGroupDescription']['language']['languageId'])
    expect(entity.description).to eq(values['goodsNomenclatureGroupDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureGroupDescription']['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureIndent sample' do
    values = {
      'sid' => '27652',
      'goodsNomenclatureItemId' => '0102901019',
      'produclineSuffix' => '80',
      'goodsNomenclatureIndents' => {
        'sid' => '28131',
        'validityStartDate' => '1992-03-01T00:00:00',
        'numberIndents' => 5,
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureIndentMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureIndent)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_indent_sid.to_s).to eq(values['goodsNomenclatureIndents']['sid'])
    expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
    expect(entity.validity_start_date).to eq(values['goodsNomenclatureIndents']['validityStartDate'])
    expect(entity.number_indents).to eq(values['goodsNomenclatureIndents']['numberIndents'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
    expect(entity.productline_suffix).to eq(values['produclineSuffix'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureIndents']['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureOrigin sample' do
    values = {
      'sid' => '27652',
      'produclineSuffix' => '80',
      'goodsNomenclatureItemId' => '0102901019',
      'goodsNomenclatureOrigin' => {
        'derivedGoodsNomenclatureItemId' => '0100000000',
        'derivedProductlineSuffix' => '80',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureOriginMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureOrigin)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
    expect(entity.derived_goods_nomenclature_item_id).to eq(values['goodsNomenclatureOrigin']['derivedGoodsNomenclatureItemId'])
    expect(entity.derived_productline_suffix).to eq(values['goodsNomenclatureOrigin']['derivedProductlineSuffix'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
    expect(entity.productline_suffix).to eq(values['produclineSuffix'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureOrigin']['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureSuccessor sample' do
    values = {
      'sid' => '27652',
      'goodsNomenclatureItemId' => '0102903131',
      'produclineSuffix' => '10',
      'goodsNomenclatureSuccessor' => {
        'absorbedGoodsNomenclatureItemId' => '0101901100',
        'absorbedProductlineSuffix' => '80',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureSuccessorMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureSuccessor)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
    expect(entity.absorbed_goods_nomenclature_item_id).to eq(values['goodsNomenclatureSuccessor']['absorbedGoodsNomenclatureItemId'])
    expect(entity.absorbed_productline_suffix).to eq(values['goodsNomenclatureSuccessor']['absorbedProductlineSuffix'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
    expect(entity.productline_suffix).to eq(values['produclineSuffix'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureSuccessor']['metainfo']['transactionDate']))
  end

  it 'Language sample' do
    values = {
      'languageId' => 'EN',
      'validityStartDate' => '1992-03-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::LanguageMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(Language)
    expect(entity).to be_valid
    expect(entity.language_id).to eq(values['languageId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'LanguageDescription sample' do
    values = {
      'languageId' => 'EN',
      'languageDescription' => {
        'description' => 'English',
        'language' => 'EN',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::LanguageDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(LanguageDescription)
    expect(entity).to be_valid
    expect(entity.language_code_id).to eq(values['languageDescription']['language'])
    expect(entity.language_id).to eq(values['languageId'])
    expect(entity.description).to eq(values['languageDescription']['description'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['languageDescription']['metainfo']['transactionDate']))
  end

  it 'GoodsNomenclatureDescriptionPeriod sample' do
    values = {
      'sid' => '27652',
      'goodsNomenclatureItemId' => '0102901019',
      'produclineSuffix' => '80',
      'goodsNomenclatureDescriptionPeriod' => {
        'sid' => '30993',
        'validityStartDate' => '1992-03-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::GoodsNomenclatureDescriptionPeriodMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(GoodsNomenclatureDescriptionPeriod)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_description_period_sid.to_s).to eq(values['goodsNomenclatureDescriptionPeriod']['sid'])
    expect(entity.goods_nomenclature_sid.to_s).to eq(values['sid'])
    expect(entity.validity_start_date).to eq(values['goodsNomenclatureDescriptionPeriod']['validityStartDate'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
    expect(entity.productline_suffix).to eq(values['produclineSuffix'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['goodsNomenclatureDescriptionPeriod']['metainfo']['transactionDate']))
  end

  it 'Measure sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measureType' => {
        'measureTypeId' => '468',
      },
      'geographicalArea' => {
        'sid' => '11881',
        'geographicalAreaId' => '1011',
      },
      'goodsNomenclature' => {
        'sid' => '22118',
        'goodsNomenclatureItemId' => '0102900500',
      },
      'measureGeneratingRegulationRole' => { 'regulationRoleTypeId' => '1' },
      'measureGeneratingRegulationId' => 'IYY99990',
      'justificationRegulationRole' => { 'regulationRoleTypeId' => '1' },
      'justificationRegulationId' => 'IYY99990',
      'stoppedFlag' => '0',
      'ordernumber' => '094281',
      'additionalCode' => {
        'sid' => '11822',
        'additionalCodeCode' => '912',
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
      },
      'reductionIndicator' => '35',
      'exportRefundNomenclature' => {
        'sid' => '19911',
      },
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(Measure)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.measure_type_id).to eq(values['measureType']['measureTypeId'])
    expect(entity.geographical_area_id).to eq(values['geographicalArea']['geographicalAreaId'])
    expect(entity.geographical_area_sid.to_s).to eq(values['geographicalArea']['sid'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclature']['goodsNomenclatureItemId'])
    expect(entity.goods_nomenclature_sid.to_s).to eq(values['goodsNomenclature']['sid'])
    expect(entity.measure_generating_regulation_role.to_s).to eq(values['measureGeneratingRegulationRole']['regulationRoleTypeId'])
    expect(entity.measure_generating_regulation_id).to eq(values['measureGeneratingRegulationId'])
    expect(entity.justification_regulation_role.to_s).to eq(values['justificationRegulationRole']['regulationRoleTypeId'])
    expect(entity.justification_regulation_id).to eq(values['justificationRegulationId'])
    expect(entity.ordernumber).to eq(values['ordernumber'])
    expect(entity.additional_code_type_id).to eq(values['additionalCode']['additionalCodeType']['additionalCodeTypeId'])
    expect(entity.additional_code_id).to eq(values['additionalCode']['additionalCodeCode'])
    expect(entity.additional_code_sid.to_s).to eq(values['additionalCode']['sid'])
    expect(entity.reduction_indicator.to_s).to eq(values['reductionIndicator'])
    expect(entity.export_refund_nomenclature_sid.to_s).to eq(values['exportRefundNomenclature']['sid'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.stopped_flag).to eq(false)
    expect(entity.national).to eq(true)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasurePartialTemporaryStop sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measurePartialTemporaryStop' => {
        'sid' => '22134',
        'validityStartDate' => '1971-03-03T00:00:00',
        'validityEndDate' => '2018-02-01T00:00:00',
        'partialTemporaryStopRegulationId' => 'R1312020',
        'partialTemporaryStopRegulationOfficialjournalNumber' => 'L 321',
        'partialTemporaryStopRegulationOfficialjournalPage' => '1',
        'abrogationRegulationId' => 'R1312021',
        'abrogationRegulationOfficialjournalNumber' => 'L 323',
        'abrogationRegulationOfficialjournalPage' => '2',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-07-25T21:03:21',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasurePartialTemporaryStopMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasurePartialTemporaryStop)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.validity_start_date).to eq(values['measurePartialTemporaryStop']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['measurePartialTemporaryStop']['validityEndDate'])
    expect(entity.partial_temporary_stop_regulation_id).to eq(values['measurePartialTemporaryStop']['partialTemporaryStopRegulationId'])
    expect(entity.partial_temporary_stop_regulation_officialjournal_number).to eq(values['measurePartialTemporaryStop']['partialTemporaryStopRegulationOfficialjournalNumber'])
    expect(entity.partial_temporary_stop_regulation_officialjournal_page.to_s).to eq(values['measurePartialTemporaryStop']['partialTemporaryStopRegulationOfficialjournalPage'])
    expect(entity.abrogation_regulation_id).to eq(values['measurePartialTemporaryStop']['abrogationRegulationId'])
    expect(entity.abrogation_regulation_officialjournal_number).to eq(values['measurePartialTemporaryStop']['abrogationRegulationOfficialjournalNumber'])
    expect(entity.abrogation_regulation_officialjournal_page.to_s).to eq(values['measurePartialTemporaryStop']['abrogationRegulationOfficialjournalPage'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measurePartialTemporaryStop']['metainfo']['transactionDate']))
  end

  it 'MeasureAction sample' do
    values = {
      'actionCode' => '29',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureActionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureAction)
    expect(entity).to be_valid
    expect(entity.action_code).to eq(values['actionCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasureActionDescription sample' do
    values = {
      'actionCode' => '29',
      'measureActionDescription' => {
        'description' => 'Import/export allowed after control',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeasureActionDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureActionDescription)
    expect(entity).to be_valid
    expect(entity.action_code).to eq(values['actionCode'])
    expect(entity.language_id).to eq(values['measureActionDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measureActionDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureActionDescription']['metainfo']['transactionDate']))
  end

  it 'RegulationGroup sample' do
    values = {
      'hjid' => '440103',
      'regulationGroupId' => '123',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'T',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::RegulationGroupMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(RegulationGroup)
    expect(entity).to be_valid
    expect(entity.regulation_group_id).to eq(values['regulationGroupId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.national).to be_falsey
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'RegulationGroupDescription sample' do
    values = {
      'hjid' => '440103',
      'regulationGroupId' => '123',
      'regulationGroupDescription' => {
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::RegulationGroupDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(RegulationGroupDescription)
    expect(entity).to be_valid
    expect(entity.regulation_group_id).to eq(values['regulationGroupId'])
    expect(entity.language_id).to eq(values['regulationGroupDescription']['language']['languageId'])
    expect(entity.description).to eq(values['regulationGroupDescription']['description'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['regulationGroupDescription']['metainfo']['transactionDate']))
  end

  it 'RegulationReplacement sample' do
    values = {
      'replacedRegulationRole' => '1',
      'replacingRegulationRole' => '1',
      'replacedRegulationId' => 'C9600110',
      'replacingRegulationId' => 'R9608580',
      'geographicalArea' => {
        'geographicalAreaId' => '1011',
      },
      'measureType' => {
        'measureTypeId' => '2',
      },
      'chapterHeading' => '123',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::RegulationReplacementMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(RegulationReplacement)
    expect(entity).to be_valid
    expect(entity.geographical_area_id).to eq(values['geographicalArea']['geographicalAreaId'])
    expect(entity.replacing_regulation_role.to_s).to eq(values['replacingRegulationRole'])
    expect(entity.replacing_regulation_id).to eq(values['replacingRegulationId'])
    expect(entity.replaced_regulation_role.to_s).to eq(values['replacedRegulationRole'])
    expect(entity.replaced_regulation_id).to eq(values['replacedRegulationId'])
    expect(entity.chapter_heading).to eq(values['chapterHeading'])
    expect(entity.measure_type_id).to eq(values['measureType']['measureTypeId'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'RegulationRoleType sample' do
    values = {
      'regulationRoleTypeId' => '1',
      'validityStartDate' => '1970-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::RegulationRoleTypeMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(RegulationRoleType)
    expect(entity).to be_valid
    expect(entity.regulation_role_type_id.to_s).to eq(values['regulationRoleTypeId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'RegulationRoleTypeDescription sample' do
    values = {
      'regulationRoleTypeId' => '1',
      'regulationRoleTypeDescription' => {
        'description' => 'Base regulation',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::RegulationRoleTypeDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(RegulationRoleTypeDescription)
    expect(entity).to be_valid
    expect(entity.regulation_role_type_id).to eq(values['regulationRoleTypeId'])
    expect(entity.language_id).to eq(values['regulationRoleTypeDescription']['language']['languageId'])
    expect(entity.description).to eq(values['regulationRoleTypeDescription']['description'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['regulationRoleTypeDescription']['metainfo']['transactionDate']))
  end

  it 'MonetaryUnit sample' do
    values = {
      'monetaryUnitCode' => 'IEP',
      'validityStartDate' => '1970-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MonetaryUnitMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MonetaryUnit)
    expect(entity).to be_valid
    expect(entity.monetary_unit_code).to eq(values['monetaryUnitCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MonetaryUnitDescription sample' do
    values = {
      'monetaryUnitCode' => 'IEP',
      'monetaryUnitDescription' => {
        'description' => 'Irish pound',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MonetaryUnitDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MonetaryUnitDescription)
    expect(entity).to be_valid
    expect(entity.monetary_unit_code).to eq(values['monetaryUnitCode'])
    expect(entity.language_id).to eq(values['monetaryUnitDescription']['language']['languageId'])
    expect(entity.description).to eq(values['monetaryUnitDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['monetaryUnitDescription']['metainfo']['transactionDate']))
  end

  it 'NomenclatureGroupMembership sample' do
    values = {
      'sid' => 27_640,
      'produclineSuffix' => '80',
      'goodsNomenclatureItemId' => '0102900500',
      'nomenclatureGroupMembership' => {
        'goodsNomenclatureGroup' => {
          'goodsNomenclatureGroupId' => '010000',
          'goodsNomenclatureGroupType' => 'B',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::NomenclatureGroupMembershipMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(NomenclatureGroupMembership)
    expect(entity).to be_valid
    expect(entity.goods_nomenclature_sid).to eq(values['sid'])
    expect(entity.goods_nomenclature_group_type).to eq(values['nomenclatureGroupMembership']['goodsNomenclatureGroup']['goodsNomenclatureGroupType'])
    expect(entity.goods_nomenclature_group_id).to eq(values['nomenclatureGroupMembership']['goodsNomenclatureGroup']['goodsNomenclatureGroupId'])
    expect(entity.validity_start_date).to eq(values['nomenclatureGroupMembership']['validityStartDate'])
    expect(entity.goods_nomenclature_item_id).to eq(values['goodsNomenclatureItemId'])
    expect(entity.productline_suffix).to eq(values['produclineSuffix'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['nomenclatureGroupMembership']['metainfo']['transactionDate']))
  end

  it 'MonetaryExchangePeriod sample' do
    values = {
      'sid' => '2927',
      'validityStartDate' => '2015-03-01T00:00:00',
      'monetaryUnit' => {
        'monetaryUnitCode' => 'EUR',
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MonetaryExchangePeriodMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MonetaryExchangePeriod)
    expect(entity).to be_valid
    expect(entity.monetary_exchange_period_sid.to_s).to eq(values['sid'])
    expect(entity.parent_monetary_unit_code).to eq(values['monetaryUnit']['monetaryUnitCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MonetaryExchangeRate sample' do
    values = {
      'sid' => 2927,
      'validityStartDate' => '2015-03-01T00:00:00',
      'monetaryExchangeRate' => {
        'childMonetaryUnitCode' => 'SEK',
        'exchangeRate' => '0.9123',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-07-29T21:14:33',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MonetaryExchangeRateMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MonetaryExchangeRate)
    expect(entity).to be_valid
    expect(entity.monetary_exchange_period_sid).to eq(values['sid'])
    expect(entity.child_monetary_unit_code).to eq(values['monetaryExchangeRate']['childMonetaryUnitCode'])
    expect(entity.exchange_rate.to_s).to eq(values['monetaryExchangeRate']['exchangeRate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['monetaryExchangeRate']['metainfo']['transactionDate']))
  end

  it 'ProrogationRegulation sample' do
    values = {
      'approvedFlag' => '1',
      'publishedDate' => '1998-04-01T00:00:00',
      'informationText' => '474 LPQ-TEXT-RU',
      'officialjournalPage' => '52',
      'replacementIndicator' => '0',
      'officialjournalNumber' => 'L 100',
      'prorogationRegulationId' => 'R9807290',
      'regulationRoleType' => {
        'regulationRoleTypeId' => '5',
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::ProrogationRegulationMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(ProrogationRegulation)
    expect(entity).to be_valid
    expect(entity.prorogation_regulation_id).to eq(values['prorogationRegulationId'])
    expect(entity.prorogation_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.published_date).to eq(Date.parse(values['publishedDate']))
    expect(entity.officialjournal_number).to eq(values['officialjournalNumber'])
    expect(entity.officialjournal_page.to_s).to eq(values['officialjournalPage'])
    expect(entity.replacement_indicator.to_s).to eq(values['replacementIndicator'])
    expect(entity.information_text).to eq(values['informationText'])
    expect(entity.approved_flag).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'ProrogationRegulationAction sample' do
    values = {
      'prorogationRegulationId' => 'C123X324',
      'regulationRoleType' => {
        'regulationRoleTypeId' => '4',
      },
      'prorogationRegulationAction' => {
        'prorogatedDate' => '1998-04-01T00:00:00',
        'prorogatedRegulationId' => 'P423X824',
        'prorogatedRegulationRole' => '1',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::ProrogationRegulationActionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(ProrogationRegulationAction)
    expect(entity).to be_valid
    expect(entity.prorogation_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.prorogation_regulation_id).to eq(values['prorogationRegulationId'])
    expect(entity.prorogated_regulation_role.to_s).to eq(values['prorogationRegulationAction']['prorogatedRegulationRole'])
    expect(entity.prorogated_regulation_id).to eq(values['prorogationRegulationAction']['prorogatedRegulationId'])
    expect(entity.prorogated_date).to eq(Date.parse(values['prorogationRegulationAction']['prorogatedDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['prorogationRegulationAction']['metainfo']['transactionDate']))
  end

  it 'QuotaDefinition sample' do
    values = {
      'sid' => '12113',
      'volume' => '30.000',
      'initialVolume' => '30.000',
      'maximumPrecision' => '3',
      'criticalThreshold' => '75',
      'criticalState' => 'N',
      'description' => 'some description',
      'quotaOrderNumber' => {
        'sid' => '1485',
        'quotaOrderNumberId' => '092607',
      },
      'measurementUnit' => {
        'measurementUnitCode' => 'KGM',
      },
      'measurementUnitQualifier' => {
        'measurementUnitQualifierCode' => 'X',
      },
      'monetaryUnit' => {
        'monetaryUnitCode' => 'EUR',
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaDefinitionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaDefinition)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.quota_order_number_id).to eq(values['quotaOrderNumber']['quotaOrderNumberId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.quota_order_number_sid.to_s).to eq(values['quotaOrderNumber']['sid'])
    expect(entity.volume).to eq(30)
    expect(entity.initial_volume).to eq(30)
    expect(entity.description).to eq(values['description'])
    expect(entity.monetary_unit_code).to eq(values['monetaryUnit']['monetaryUnitCode'])
    expect(entity.measurement_unit_code).to eq(values['measurementUnit']['measurementUnitCode'])
    expect(entity.measurement_unit_qualifier_code).to eq(values['measurementUnitQualifier']['measurementUnitQualifierCode'])
    expect(entity.maximum_precision.to_s.to_s).to eq(values['maximumPrecision'])
    expect(entity.critical_state).to eq(values['criticalState'])
    expect(entity.critical_threshold.to_s).to eq(values['criticalThreshold'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'QuotaAssociation sample' do
    values = {
      'sid' => '12112',
      'volume' => '30.000',
      'initialVolume' => '30.000',
      'maximumPrecision' => '3',
      'criticalThreshold' => '75',
      'criticalState' => 'N',
      'quotaAssociation' => {
        'subQuotaDefinition' => {
          'sid' => '12341',
        },
        'relationType' => 'EQ',
        'coefficient' => '1.42',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaAssociationMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaAssociation)
    expect(entity).to be_valid
    expect(entity.main_quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.sub_quota_definition_sid.to_s).to eq(values['quotaAssociation']['subQuotaDefinition']['sid'])
    expect(entity.relation_type).to eq(values['quotaAssociation']['relationType'])
    expect(entity.coefficient.to_s).to eq(values['quotaAssociation']['coefficient'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'QuotaBalanceEvent sample' do
    values = {
      'sid' => '12113',
      'quotaBalanceEvent' => {
        'hjid' => '1485',
        'occurrenceTimestamp' => '2005-12-15T16:37:59',
        'lastImportDateInAllocation' => '4712-12-31T23:59:59',
        'oldBalance' => '12.2',
        'newBalance' => '13.4',
        'importedAmount' => '57173433.0',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaBalanceEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaBalanceEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(values['quotaBalanceEvent']['occurrenceTimestamp'])
    expect(entity.last_import_date_in_allocation).to eq(Date.parse(values['quotaBalanceEvent']['lastImportDateInAllocation']))
    expect(entity.old_balance.to_s).to eq(values['quotaBalanceEvent']['oldBalance'])
    expect(entity.new_balance.to_s).to eq(values['quotaBalanceEvent']['newBalance'])
    expect(entity.imported_amount.to_s).to eq(values['quotaBalanceEvent']['importedAmount'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaBalanceEvent']['metainfo']['transactionDate']))
  end

  it 'QuotaCriticalEvent sample' do
    values = {
      'sid' => '12113',
      'quotaCriticalEvent' => {
        'hjid' => '1485',
        'occurrenceTimestamp' => '2005-12-15T16:37:59',
        'criticalState' => 'Y',
        'criticalStateChangeDate' => '2004-02-16T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaCriticalEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaCriticalEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(values['quotaCriticalEvent']['occurrenceTimestamp'])
    expect(entity.critical_state).to eq(values['quotaCriticalEvent']['criticalState'])
    expect(entity.critical_state_change_date).to eq(Date.parse(values['quotaCriticalEvent']['criticalStateChangeDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaCriticalEvent']['metainfo']['transactionDate']))
  end

  it 'QuotaExhaustionEvent sample' do
    values = {
      'sid' => '12113',
      'quotaExhaustionEvent' => {
        'hjid' => '1485',
        'occurrenceTimestamp' => '2005-12-15T16:37:59',
        'exhaustionDate' => '2004-02-16T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaExhaustionEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaExhaustionEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(values['quotaExhaustionEvent']['occurrenceTimestamp'])
    expect(entity.exhaustion_date).to eq(Date.parse(values['quotaExhaustionEvent']['exhaustionDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaExhaustionEvent']['metainfo']['transactionDate']))
  end

  it 'QuotaReopeningEvent sample' do
    values = {
      'sid' => '12113',
      'quotaReopeningEvent' => {
        'hjid' => '1485',
        'occurrenceTimestamp' => '2005-12-15T16:37:59',
        'reopeningDate' => '2004-02-16T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaReopeningEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaReopeningEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(values['quotaReopeningEvent']['occurrenceTimestamp'])
    expect(entity.reopening_date).to eq(Date.parse(values['quotaReopeningEvent']['reopeningDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaReopeningEvent']['metainfo']['transactionDate']))
  end

  it 'QuotaUnsuspensionEvent sample' do
    values = {
      'sid' => '12113',
      'quotaUnsuspensionEvent' => {
        'hjid' => '1485',
        'occurrenceTimestamp' => '2005-12-15T16:37:59',
        'unsuspensionDate' => '2004-02-16T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaUnsuspensionEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaUnsuspensionEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(values['quotaUnsuspensionEvent']['occurrenceTimestamp'])
    expect(entity.unsuspension_date).to eq(Date.parse(values['quotaUnsuspensionEvent']['unsuspensionDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaUnsuspensionEvent']['metainfo']['transactionDate']))
  end

  it 'QuotaOrderNumberOrigin sample' do
    values = {
      'sid' => '12113',
      'quotaOrderNumberOrigin' => {
        'sid' => '1485',
        'geographicalArea' => {
          'sid' => '11993',
          'geographicalAreaId' => '1101',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-15T22:27:51',
          },
        },
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1971-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaOrderNumberOriginMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaOrderNumberOrigin)
    expect(entity).to be_valid
    expect(entity.quota_order_number_sid.to_s).to eq(values['sid'])
    expect(entity.quota_order_number_origin_sid.to_s).to eq(values['quotaOrderNumberOrigin']['sid'])
    expect(entity.geographical_area_id).to eq(values['quotaOrderNumberOrigin']['geographicalArea']['geographicalAreaId'])
    expect(entity.geographical_area_sid.to_s).to eq(values['quotaOrderNumberOrigin']['geographicalArea']['sid'])
    expect(entity.validity_start_date).to eq(values['quotaOrderNumberOrigin']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['quotaOrderNumberOrigin']['validityEndDate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['quotaOrderNumberOrigin']['metainfo']['transactionDate']))
  end

  it 'QuotaOrderNumberOriginExclusion sample' do
    values = {
      'sid' => '12113',
      'quotaOrderNumberOrigin' => {
        'sid' => '1485',
        'geographicalArea' => {
          'sid' => '11993',
          'geographicalAreaId' => '1101',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-15T22:27:51',
          },
        },
        'quotaOrderNumberOriginExclusion' => {
          'geographicalArea' => {
            'sid' => '11993',
            'geographicalAreaId' => '1101',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-07-15T22:27:51',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-10-14T11:55:34',
          },
        },
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1971-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaOrderNumberOriginExclusionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaOrderNumberOriginExclusion)
    expect(entity).to be_valid
    expect(entity.quota_order_number_origin_sid.to_s).to eq(values['quotaOrderNumberOrigin']['sid'])
    expect(entity.excluded_geographical_area_sid.to_s).to eq(values['quotaOrderNumberOrigin']['quotaOrderNumberOriginExclusion']['geographicalArea']['sid'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['quotaOrderNumberOrigin']['quotaOrderNumberOriginExclusion']['metainfo']['transactionDate']))
  end

  it 'QuotaSuspensionPeriod sample' do
    values = {
      'sid' => '12113',
      'quotaSuspensionPeriod' => {
        'sid' => '1485',
        'suspensionStartDate' => '2005-12-15T16:37:59',
        'suspensionEndDate' => '2004-02-16T00:00:00',
        'description' => 'Description',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-04-11T10:05:31',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaSuspensionPeriodMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaSuspensionPeriod)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.quota_suspension_period_sid.to_s).to eq(values['quotaSuspensionPeriod']['sid'])
    expect(entity.suspension_start_date).to eq(Date.parse(values['quotaSuspensionPeriod']['suspensionStartDate']))
    expect(entity.suspension_end_date).to eq(Date.parse(values['quotaSuspensionPeriod']['suspensionEndDate']))
    expect(entity.description).to eq(values['quotaSuspensionPeriod']['description'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['quotaSuspensionPeriod']['metainfo']['transactionDate']))
  end

  it 'MeasureConditionCode sample' do
    values = {
      'conditionCode' => 'A',
      'validityStartDate' => '1970-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureConditionCodeMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureConditionCode)
    expect(entity).to be_valid
    expect(entity.condition_code).to eq(values['conditionCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasureConditionCodeDescription sample' do
    values = {
      'conditionCode' => 'A',
      'measureConditionCodeDescription' => {
        'description' => 'Presentation of an anti-dumping/countervailing document',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeasureConditionCodeDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureConditionCodeDescription)
    expect(entity).to be_valid
    expect(entity.condition_code).to eq(values['conditionCode'])
    expect(entity.language_id).to eq(values['measureConditionCodeDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measureConditionCodeDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureConditionCodeDescription']['metainfo']['transactionDate']))
  end

  it 'MeasureType sample' do
    values = {
      'measureTypeId' => '487',
      'validityStartDate' => '1970-01-01T00:00:00',
      'tradeMovementCode' => '0',
      'priorityCode' => '1',
      'measureComponentApplicableCode' => '1',
      'originDestCode' => '0',
      'orderNumberCaptureCode' => '2',
      'measureExplosionLevel' => '10',
      'measureTypeSeries' => {
        'measureTypeSeriesId' => 'M',
      },
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureTypeMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureType)
    expect(entity).to be_valid
    expect(entity.measure_type_id).to eq(values['measureTypeId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.trade_movement_code.to_s).to eq(values['tradeMovementCode'])
    expect(entity.priority_code.to_s).to eq(values['priorityCode'])
    expect(entity.measure_component_applicable_code.to_s).to eq(values['measureComponentApplicableCode'])
    expect(entity.origin_dest_code.to_s).to eq(values['originDestCode'])
    expect(entity.order_number_capture_code.to_s).to eq(values['orderNumberCaptureCode'])
    expect(entity.measure_explosion_level.to_s).to eq(values['measureExplosionLevel'])
    expect(entity.measure_type_series_id).to eq(values['measureTypeSeries']['measureTypeSeriesId'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasureTypeDescription sample' do
    values = {
      'measureTypeId' => '487',
      'measureTypeDescription' => {
        'description' => 'Representative price (poultry)',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeasureTypeDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureTypeDescription)
    expect(entity).to be_valid
    expect(entity.measure_type_id).to eq(values['measureTypeId'])
    expect(entity.language_id).to eq(values['measureTypeDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measureTypeDescription']['description'])
    expect(entity.national).to be_truthy
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureTypeDescription']['metainfo']['transactionDate']))
  end

  it 'MeasureTypeSeries sample' do
    values = {
      'measureTypeSeriesId' => 'N',
      'validityStartDate' => '1970-01-01T00:00:00',
      'measureTypeCombination' => '1',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureTypeSeriesMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureTypeSeries)
    expect(entity).to be_valid
    expect(entity.measure_type_series_id).to eq(values['measureTypeSeriesId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.measure_type_combination.to_s).to eq(values['measureTypeCombination'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasureTypeSeriesDescription sample' do
    values = {
      'measureTypeSeriesId' => 'N',
      'measureTypeSeriesDescription' => {
        'description' => 'Posterior surveillance',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeasureTypeSeriesDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureTypeSeriesDescription)
    expect(entity).to be_valid
    expect(entity.measure_type_series_id).to eq(values['measureTypeSeriesId'])
    expect(entity.language_id).to eq(values['measureTypeSeriesDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measureTypeSeriesDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureTypeSeriesDescription']['metainfo']['transactionDate']))
  end

  it 'Measurement sample' do
    values = {
      'measurementUnitCode' => 'DDS',
      'validityStartDate' => '1971-02-11T00:00:00',
      'validityEndDate' => '1972-01-04T00:00:00',
      'metainfo' => {
        'opType' => 'C',
        'transactionDate' => '2017-07-29T20:04:37',
      },
      'measurementUnitQualifier' => {
        'measurementUnitQualifierCode' => 'X',
      },
    }
    subject = CdsImporter::EntityMapper::MeasurementMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(Measurement)
    expect(entity).to be_valid
    expect(entity.measurement_unit_code).to eq(values['measurementUnitCode'])
    expect(entity.measurement_unit_qualifier_code).to eq(values['measurementUnitQualifier']['measurementUnitQualifierCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasurementUnit sample' do
    values = {
      'measurementUnitCode' => 'MWH',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1971-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasurementUnitMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasurementUnit)
    expect(entity).to be_valid
    expect(entity.measurement_unit_code).to eq(values['measurementUnitCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasureComponent sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measureComponent' => [{
        'dutyAmount' => '12.34',
        'dutyExpression' => {
          'dutyExpressionId' => '01',
        },
        'monetaryUnit' => {
          'monetaryUnitCode' => 'EUR',
        },
        'measurementUnit' => {
          'measurementUnitCode' => 'DTN',
        },
        'measurementUnitQualifier' => {
          'measurementUnitQualifierCode' => '56',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },

                             {
                               'dutyAmount' => '32.11',
                               'dutyExpression' => {
                                 'dutyExpressionId' => '02',
                               },
                               'monetaryUnit' => {
                                 'monetaryUnitCode' => 'EUR',
                               },
                               'measurementUnit' => {
                                 'measurementUnitCode' => 'QTN',
                               },
                               'measurementUnitQualifier' => {
                                 'measurementUnitQualifierCode' => '78',
                               },
                               'metainfo' => {
                                 'opType' => 'C',
                                 'transactionDate' => '2018-06-29T20:04:37',
                               },
                             }],
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureComponentMapper.new(values)
    entities = subject.parse
    entity = entities[0]
    expect(entities.length).to eq(2)
    expect(entity).to be_a(MeasureComponent)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.duty_expression_id).to eq(values['measureComponent'][0]['dutyExpression']['dutyExpressionId'])
    expect(entity.duty_amount.to_s).to eq(values['measureComponent'][0]['dutyAmount'])
    expect(entity.monetary_unit_code).to eq(values['measureComponent'][0]['monetaryUnit']['monetaryUnitCode'])
    expect(entity.measurement_unit_code).to eq(values['measureComponent'][0]['measurementUnit']['measurementUnitCode'])
    expect(entity.measurement_unit_qualifier_code).to eq(values['measureComponent'][0]['measurementUnitQualifier']['measurementUnitQualifierCode'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureComponent'][0]['metainfo']['transactionDate']))
  end

  it 'MeasureCondition sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measureCondition' => {
        'sid' => '3321',
        'conditionDutyAmount' => '12.34',
        'conditionSequenceNumber' => '123',
        'monetaryUnit' => {
          'monetaryUnitCode' => 'EUR',
        },
        'measurementUnit' => {
          'measurementUnitCode' => 'DTN',
        },
        'measurementUnitQualifier' => {
          'measurementUnitQualifierCode' => '56',
        },
        'measureAction' => {
          'actionCode' => '36',
        },
        'certificate' => {
          'certificateCode' => '03',
          'certificateType' => {
            'certificateTypeCode' => '05',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureConditionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureCondition)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.measure_condition_sid.to_s).to eq(values['measureCondition']['sid'])
    expect(entity.component_sequence_number.to_s).to eq(values['measureCondition']['conditionSequenceNumber'])
    expect(entity.condition_duty_amount.to_s).to eq(values['measureCondition']['conditionDutyAmount'])
    expect(entity.condition_monetary_unit_code).to eq(values['measureCondition']['monetaryUnit']['monetaryUnitCode'])
    expect(entity.condition_measurement_unit_code).to eq(values['measureCondition']['measurementUnit']['measurementUnitCode'])
    expect(entity.condition_measurement_unit_qualifier_code).to eq(values['measureCondition']['measurementUnitQualifier']['measurementUnitQualifierCode'])
    expect(entity.action_code).to eq(values['measureCondition']['measureAction']['actionCode'])
    expect(entity.certificate_type_code).to eq(values['measureCondition']['certificate']['certificateType']['certificateTypeCode'])
    expect(entity.certificate_code).to eq(values['measureCondition']['certificate']['certificateCode'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureCondition']['metainfo']['transactionDate']))
  end

  it 'MeasureConditionComponent sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measureCondition' => [
        {
          'sid' => '3321',
          'conditionDutyAmount' => '12.34',
          'conditionSequenceNumber' => '123',
          'measureConditionComponent' => [
            {
              'dutyExpression' => {
                'dutyExpressionId' => '01',
              },
              'dutyAmount' => '23.1',
              'monetaryUnit' => {
                'monetaryUnitCode' => 'USD',
              },
              'measurementUnit' => {
                'measurementUnitCode' => 'ASD',
              },
              'measurementUnitQualifier' => {
                'measurementUnitQualifierCode' => '12',
              },
              'metainfo' => {
                'opType' => 'C',
                'transactionDate' => '2017-06-29T20:04:37',
              },
            },
            {
              'dutyExpression' => {
                'dutyExpressionId' => '02',
              },
              'dutyAmount' => '123.1',
              'monetaryUnit' => {
                'monetaryUnitCode' => 'USD',
              },
              'measurementUnit' => {
                'measurementUnitCode' => 'ASD',
              },
              'measurementUnitQualifier' => {
                'measurementUnitQualifierCode' => '15',
              },
              'metainfo' => {
                'opType' => 'C',
                'transactionDate' => '2017-06-29T20:04:37',
              },
            },
          ],
          'monetaryUnit' => {
            'monetaryUnitCode' => 'EUR',
          },
          'measurementUnit' => {
            'measurementUnitCode' => 'DTN',
          },
          'measurementUnitQualifier' => {
            'measurementUnitQualifierCode' => '56',
          },
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
        {
          'sid' => '99111',
          'conditionDutyAmount' => '99.34',
          'conditionSequenceNumber' => '998',
          'measureConditionComponent' => [
            {
              'dutyExpression' => {
                'dutyExpressionId' => '09',
              },
              'dutyAmount' => '29.1',
              'monetaryUnit' => {
                'monetaryUnitCode' => 'USD',
              },
              'measurementUnit' => {
                'measurementUnitCode' => 'ASD',
              },
              'measurementUnitQualifier' => {
                'measurementUnitQualifierCode' => '19',
              },
              'metainfo' => {
                'opType' => 'C',
                'transactionDate' => '2017-06-29T20:04:37',
              },
            },
            {
              'dutyExpression' => {
                'dutyExpressionId' => '19',
              },
              'dutyAmount' => '19.1',
              'monetaryUnit' => {
                'monetaryUnitCode' => 'USD',
              },
              'measurementUnit' => {
                'measurementUnitCode' => 'ASD',
              },
              'measurementUnitQualifier' => {
                'measurementUnitQualifierCode' => '29',
              },
              'metainfo' => {
                'opType' => 'C',
                'transactionDate' => '2017-06-29T20:04:37',
              },
            },
          ],
          'monetaryUnit' => {
            'monetaryUnitCode' => 'EUR',
          },
          'measurementUnit' => {
            'measurementUnitCode' => 'DTN',
          },
          'measurementUnitQualifier' => {
            'measurementUnitQualifierCode' => '59',
          },
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      ],
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureConditionComponentMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureConditionComponent)
    expect(entity).to be_valid
    expect(entity.measure_condition_sid.to_s).to eq(values['measureCondition'][0]['sid'])
    expect(entity.duty_expression_id).to eq(values['measureCondition'][0]['measureConditionComponent'][0]['dutyExpression']['dutyExpressionId'])
    expect(entity.duty_amount.to_s).to eq(values['measureCondition'][0]['measureConditionComponent'][0]['dutyAmount'])
    expect(entity.monetary_unit_code).to eq(values['measureCondition'][0]['measureConditionComponent'][0]['monetaryUnit']['monetaryUnitCode'])
    expect(entity.measurement_unit_code).to eq(values['measureCondition'][0]['measureConditionComponent'][0]['measurementUnit']['measurementUnitCode'])
    expect(entity.measurement_unit_qualifier_code).to eq(values['measureCondition'][0]['measureConditionComponent'][0]['measurementUnitQualifier']['measurementUnitQualifierCode'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['measureCondition'][0]['measureConditionComponent'][0]['metainfo']['transactionDate']))
  end

  it 'MeasurementUnitDescription sample' do
    values = {
      'measurementUnitCode' => 'MWH',
      'measurementUnitDescription' => {
        'description' => '1000 kilowatt hours',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasurementUnitDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasurementUnitDescription)
    expect(entity).to be_valid
    expect(entity.measurement_unit_code).to eq(values['measurementUnitCode'])
    expect(entity.language_id).to eq(values['measurementUnitDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measurementUnitDescription']['description'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['measurementUnitDescription']['metainfo']['transactionDate']))
  end

  it 'MeasureExcludedGeographicalArea sample' do
    values = {
      'sid' => '12348',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'measureType' => {
        'measureTypeId' => '468',
      },
      'measureExcludedGeographicalArea' => {
        'geographicalArea' => {
          'sid' => '11993',
          'geographicalAreaId' => '1101',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-15T22:27:51',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-07-14T21:34:15',
        },
      },
      'geographicalArea' => {
        'sid' => '11881',
        'geographicalAreaId' => '1011',
      },
      'metainfo' => {
        'opType' => 'U',
        'origin' => 'N',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
    subject = CdsImporter::EntityMapper::MeasureExcludedGeographicalAreaMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasureExcludedGeographicalArea)
    expect(entity).to be_valid
    expect(entity.measure_sid.to_s).to eq(values['sid'])
    expect(entity.excluded_geographical_area).to eq(values['measureExcludedGeographicalArea']['geographicalArea']['geographicalAreaId'])
    expect(entity.geographical_area_sid.to_s).to eq(values['measureExcludedGeographicalArea']['geographicalArea']['sid'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measureExcludedGeographicalArea']['metainfo']['transactionDate']))
  end

  it 'MeursingAdditionalCode sample' do
    values = {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'metainfo' => {
        'opType' => 'C',
        'transactionDate' => '2016-07-27T09:20:15',
      },
    }
    subject = CdsImporter::EntityMapper::MeursingAdditionalCodeMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingAdditionalCode)
    expect(entity).to be_valid
    expect(entity.meursing_additional_code_sid.to_s).to eq(values['sid'])
    expect(entity.additional_code).to eq(values['additionalCodeCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeursingHeading sample' do
    values = {
      'meursingTablePlanId' => '03',
      'meursingHeading' => {
        'sid' => '3084',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'meursingHeadingNumber' => '20',
        'rowColumnCode' => '1',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeursingHeadingMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingHeading)
    expect(entity).to be_valid
    expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlanId'])
    expect(entity.meursing_heading_number).to eq(values['meursingHeading']['meursingHeadingNumber'])
    expect(entity.row_column_code.to_s).to eq(values['meursingHeading']['rowColumnCode'])
    expect(entity.validity_start_date).to eq(values['meursingHeading']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['meursingHeading']['validityEndDate'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['meursingHeading']['metainfo']['transactionDate']))
  end

  it 'MeursingHeadingText sample' do
    values = {
      'meursingTablePlanId' => '01',
      'meursingHeading' => {
        'sid' => '3084',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'meursingHeadingNumber' => '20',
        'rowColumnCode' => '1',
        'meursingHeadingText' => {
          'language' => {
            'languageId' => 'EN',
          },
          'description' => 'qwerty',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2016-08-21T19:21:46',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeursingHeadingTextMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingHeadingText)
    expect(entity).to be_valid
    expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlanId'])
    expect(entity.meursing_heading_number.to_s).to eq(values['meursingHeading']['meursingHeadingNumber'])
    expect(entity.row_column_code.to_s).to eq(values['meursingHeading']['rowColumnCode'])
    expect(entity.language_id).to eq(values['meursingHeading']['meursingHeadingText']['language']['languageId'])
    expect(entity.description).to eq(values['meursingHeading']['meursingHeadingText']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['meursingHeading']['meursingHeadingText']['metainfo']['transactionDate']))
  end

  it 'MeursingSubheading sample' do
    values = {
      'meursingTablePlanId' => '01',
      'validityStartDate' => '1988-01-01T00:00:00',
      'meursingHeading' => {
        'sid' => '1054',
        'validityEndDate' => '1997-07-11T22:59:59',
        'validityStartDate' => '1999-09-04T00:00:00',
        'meursingHeadingNumber' => '20',
        'rowColumnCode' => '1',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-08-27T10:20:15',
        },
        'meursingSubheading' => {
          'sid' => '3084',
          'validityEndDate' => '1996-06-14T23:59:59',
          'validityStartDate' => '1991-06-01T00:00:00',
          'subheadingSequenceNumber' => '11',
          'description' => 'Some text.',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2016-07-27T09:20:17',
          },
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeursingSubheadingMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingSubheading)
    expect(entity).to be_valid
    expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlanId'])
    expect(entity.meursing_heading_number.to_s).to eq(values['meursingHeading']['meursingHeadingNumber'])
    expect(entity.row_column_code.to_s).to eq(values['meursingHeading']['rowColumnCode'])
    expect(entity.subheading_sequence_number.to_s).to eq(values['meursingHeading']['meursingSubheading']['subheadingSequenceNumber'])
    expect(entity.description).to eq(values['meursingHeading']['meursingSubheading']['description'])
    expect(entity.validity_start_date).to eq(values['meursingHeading']['meursingSubheading']['validityStartDate'])
    expect(entity.validity_end_date).to eq(values['meursingHeading']['meursingSubheading']['validityEndDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['meursingHeading']['meursingSubheading']['metainfo']['transactionDate']))
  end

  it 'MeursingTableCellComponent sample' do
    values = {
      'sid' => '359',
      'additionalCodeCode' => '475',
      'validityStartDate' => '1988-01-01T00:00:00',
      'meursingCellComponent' => {
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-06-22T10:20:13',
        },
        'validityStartDate' => '2016-08-22T11:30:13',
        'validityEndtDate' => '2026-08-22T11:30:13',
        'meursingSubheading' => {
          'hjid' => '508826',
          'subheadingSequenceNumber' => '150',
          'meursingHeading' => {
            'meursingHeadingNumber' => '10',
            'rowColumnCode' => '1',
            'meursingTablePlan' => {
              'meursingTablePlanId' => '01',
            },
          },
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeursingTableCellComponentMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingTableCellComponent)
    expect(entity).to be_valid
    expect(entity.meursing_additional_code_sid.to_s).to eq(values['sid'])
    expect(entity.additional_code).to eq(values['additionalCodeCode'])
    expect(entity.meursing_table_plan_id).to eq(values['meursingCellComponent']['meursingSubheading']['meursingHeading']['meursingTablePlan']['meursingTablePlanId'])
    expect(entity.heading_number.to_s).to eq(values['meursingCellComponent']['meursingSubheading']['meursingHeading']['meursingHeadingNumber'])
    expect(entity.row_column_code.to_s).to eq(values['meursingCellComponent']['meursingSubheading']['meursingHeading']['rowColumnCode'])
    expect(entity.subheading_sequence_number.to_s).to eq(values['meursingCellComponent']['meursingSubheading']['subheadingSequenceNumber'])
    expect(entity.operation).to eq(:create)
    expect(entity.operation_date).to eq(Date.parse(values['meursingCellComponent']['metainfo']['transactionDate']))
  end

  it 'MeasurementUnitQualifier sample' do
    values = {
      'measurementUnitQualifierCode' => 'B',
      'validityStartDate' => '1970-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:17',
      },
    }
    subject = CdsImporter::EntityMapper::MeasurementUnitQualifierMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasurementUnitQualifier)
    expect(entity).to be_valid
    expect(entity.measurement_unit_qualifier_code).to eq(values['measurementUnitQualifierCode'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'MeasurementUnitQualifierDescription sample' do
    values = {
      'measurementUnitQualifierCode' => 'B',
      'measurementUnitQualifierDescription' => {
        'description' => 'per flask',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      },
    }
    subject = CdsImporter::EntityMapper::MeasurementUnitQualifierDescriptionMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeasurementUnitQualifierDescription)
    expect(entity).to be_valid
    expect(entity.measurement_unit_qualifier_code).to eq(values['measurementUnitQualifierCode'])
    expect(entity.language_id).to eq(values['measurementUnitQualifierDescription']['language']['languageId'])
    expect(entity.description).to eq(values['measurementUnitQualifierDescription']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['measurementUnitQualifierDescription']['metainfo']['transactionDate']))
  end

  it 'MeursingTablePlan sample' do
    values = {
      'meursingTablePlanId' => '01',
      'validityStartDate' => '1988-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:17',
      },
    }
    subject = CdsImporter::EntityMapper::MeursingTablePlanMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(MeursingTablePlan)
    expect(entity).to be_valid
    expect(entity.meursing_table_plan_id).to eq(values['meursingTablePlanId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'ModificationRegulation sample' do
    values = {
      'modificationRegulationId' => 'R9617341',
      'publishedDate' => '1996-09-19T00:00:00',
      'officialjournalNumber' => 'L 238',
      'officialjournalPage' => '1',
      'replacementIndicator' => '0',
      'stoppedFlag' => '1',
      'approvedFlag' => '1',
      'informationText' => 'NC - 01.01.1997 (mes. 110/111)',
      'effectiveEndDate' => '1996-06-30T23:59:59',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '2019-03-03T00:00:00',
      'regulationRoleType' => {
        'regulationRoleTypeId' => '5',
      },
      'baseRegulation' => {
        'baseRegulationId' => 'R8726581',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '8',
        },
      },
      'explicitAbrogationRegulation' => {
        'explicitAbrogationRegulationId' => '321',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '7',
        },
      },
      'completeAbrogationRegulation' => {
        'completeAbrogationRegulationId' => '123',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:17',
      },
    }
    subject = CdsImporter::EntityMapper::ModificationRegulationMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(ModificationRegulation)
    expect(entity).to be_valid
    expect(entity.modification_regulation_id).to eq(values['modificationRegulationId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.published_date).to eq(Date.parse(values['publishedDate']))
    expect(entity.officialjournal_number).to eq(values['officialjournalNumber'])
    expect(entity.officialjournal_page.to_s).to eq(values['officialjournalPage'])
    expect(entity.base_regulation_id).to eq(values['baseRegulation']['baseRegulationId'])
    expect(entity.replacement_indicator.to_s).to eq(values['replacementIndicator'])
    expect(entity.stopped_flag).to be_truthy
    expect(entity.information_text).to eq(values['informationText'])
    expect(entity.approved_flag).to be_truthy
    expect(entity.effective_end_date).to eq(values['effectiveEndDate'])
    expect(entity.validity_end_date).to eq(values['validityEndDate'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.modification_regulation_role.to_s).to eq(values['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.base_regulation_role.to_s).to eq(values['baseRegulation']['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.explicit_abrogation_regulation_role.to_s).to eq(values['explicitAbrogationRegulation']['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.explicit_abrogation_regulation_id).to eq(values['explicitAbrogationRegulation']['explicitAbrogationRegulationId'])
    expect(entity.complete_abrogation_regulation_role.to_s).to eq(values['completeAbrogationRegulation']['regulationRoleType']['regulationRoleTypeId'])
    expect(entity.complete_abrogation_regulation_id).to eq(values['completeAbrogationRegulation']['completeAbrogationRegulationId'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'QuotaBlockingPeriod sample' do
    values = {
      'sid' => '13321',
      'quotaBlockingPeriod' => {
        'quotaBlockingPeriodSid' => '16811',
        'blockingStartDate' => '2004-01-09T00:00:00',
        'blockingEndDate' => '2004-01-30T00:00:00',
        'blockingPeriodType' => 1,
        'description' => 'Council adoption anticipated 10.2.2004',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      },
    }
    subject = CdsImporter::EntityMapper::QuotaBlockingPeriodMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaBlockingPeriod)
    expect(entity).to be_valid
    expect(entity.quota_blocking_period_sid.to_s).to eq(values['quotaBlockingPeriod']['quotaBlockingPeriodSid'])
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.blocking_start_date).to eq(Date.parse(values['quotaBlockingPeriod']['blockingStartDate']))
    expect(entity.blocking_end_date).to eq(Date.parse(values['quotaBlockingPeriod']['blockingEndDate']))
    expect(entity.blocking_period_type).to eq(values['quotaBlockingPeriod']['blockingPeriodType'])
    expect(entity.description).to eq(values['quotaBlockingPeriod']['description'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaBlockingPeriod']['metainfo']['transactionDate']))
  end

  it 'QuotaOrderNumber sample' do
    values = {
      'sid' => '21811',
      'quotaOrderNumberId' => '090718',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:17',
      },
    }
    subject = CdsImporter::EntityMapper::QuotaOrderNumberMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaOrderNumber)
    expect(entity).to be_valid
    expect(entity.quota_order_number_sid.to_s).to eq(values['sid'])
    expect(entity.quota_order_number_id).to eq(values['quotaOrderNumberId'])
    expect(entity.validity_start_date).to eq(values['validityStartDate'])
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['metainfo']['transactionDate']))
  end

  it 'QuotaUnblockingEvent sample' do
    values = {
      'sid' => '13412',
      'quotaUnblockingEvent' => {
        'occurrenceTimestamp' => '2004-02-16T14:10:40+0000',
        'unblockingDate' => '2004-02-16T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      },
    }
    subject = CdsImporter::EntityMapper::QuotaUnblockingEventMapper.new(values)
    entity = subject.parse[0]
    expect(entity).to be_a(QuotaUnblockingEvent)
    expect(entity).to be_valid
    expect(entity.quota_definition_sid.to_s).to eq(values['sid'])
    expect(entity.occurrence_timestamp).to eq(Time.parse(values['quotaUnblockingEvent']['occurrenceTimestamp']))
    expect(entity.unblocking_date).to eq(Date.parse(values['quotaUnblockingEvent']['unblockingDate']))
    expect(entity.operation).to eq(:update)
    expect(entity.operation_date).to eq(Date.parse(values['quotaUnblockingEvent']['metainfo']['transactionDate']))
  end
end
