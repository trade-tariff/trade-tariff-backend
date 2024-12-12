require 'active_support/core_ext/hash/conversions'
require_relative 'snapshot/loaders/base'

# Dir[Rails.root.join('app/lib/snapshot/loaders/**/*.rb')].sort.each { |f| require f }

class CdsSnapshotImporter
  class ImportException < StandardError; end

  FILE = TradeTariffBackend.snapshot_importer_file_path.freeze
  BATCH_SIZE = TradeTariffBackend.snapshot_importer_batch_size

  def initialize(snapshot_update)
    @snapshot_update = snapshot_update
  end

  def import
    zip_file = TariffSynchronizer::FileService.file_as_stringio(@snapshot_update)

    Zip::File.open_buffer(zip_file) do |archive|
      archive.entries.each do |entry|
        # Read into memory
        xml_stream = entry.get_input_stream
        process(xml_stream)

        Rails.logger.info "Successfully imported Cds file: #{@snapshot_update.filename}"
      end
    end
  end

  private

  def nodes
    Loaders.constants.dup.map(&:to_s).delete_if { |name| name == 'Base' }
  end

  def process(xml_stream)
    current_node = ''
    count = 0
    batch = []

    Nokogiri::XML::Reader.from_io(xml_stream).each do |node|
      next unless nodes.include? node.name

      if !batch.empty? && (current_node != node.name || (count % BATCH_SIZE).zero?)
        Rails.logger.debug "Loading #{current_node}"
        loader = Object.const_get("Loaders::#{current_node}")
        loader.load(@snapshot_update.filename, batch)
        batch.clear
      end

      # Process current node
      attribs = Hash.from_xml(node.outer_xml)
      batch << attribs if attribs[node.name]
      current_node = node.name
      count += 1
    end

    unless batch.empty?
      Rails.logger.debug "Loading #{current_node}"
      loader = Object.const_get("Loaders::#{current_node}")
      loader.load(@snapshot_update.filename, batch)
    end
  end

  def truncate
    Object.const_get('AdditionalCode::Operation').truncate
    Object.const_get('AdditionalCodeDescription::Operation').truncate
    Object.const_get('AdditionalCodeDescriptionPeriod::Operation').truncate
    Object.const_get('AdditionalCodeType::Operation').truncate
    Object.const_get('AdditionalCodeTypeDescription::Operation').truncate
    Object.const_get('AdditionalCodeTypeMeasureType::Operation').truncate
    Object.const_get('BaseRegulation::Operation').truncate
    Object.const_get('Certificate::Operation').truncate
    Object.const_get('CertificateDescription::Operation').truncate
    Object.const_get('CertificateDescriptionPeriod::Operation').truncate
    Object.const_get('CertificateType::Operation').truncate
    Object.const_get('CertificateTypeDescription::Operation').truncate
    Object.const_get('CompleteAbrogationRegulation::Operation').truncate
    Object.const_get('DutyExpression::Operation').truncate
    Object.const_get('DutyExpressionDescription::Operation').truncate
    Object.const_get('ExplicitAbrogationRegulation::Operation').truncate
    Object.const_get('Footnote::Operation').truncate
    Object.const_get('FootnoteAssociationAdditionalCode::Operation').truncate
    Object.const_get('FootnoteAssociationGoodsNomenclature::Operation').truncate
    Object.const_get('FootnoteAssociationMeasure::Operation').truncate
    Object.const_get('FootnoteAssociationMeursingHeading::Operation').truncate
    Object.const_get('FootnoteDescription::Operation').truncate
    Object.const_get('FootnoteDescriptionPeriod::Operation').truncate
    Object.const_get('FootnoteType::Operation').truncate
    Object.const_get('FootnoteTypeDescription::Operation').truncate
    Object.const_get('FtsRegulationAction::Operation').truncate
    Object.const_get('FullTemporaryStopRegulation::Operation').truncate
    Object.const_get('GeographicalArea::Operation').truncate
    Object.const_get('GeographicalAreaDescription::Operation').truncate
    Object.const_get('GeographicalAreaDescriptionPeriod::Operation').truncate
    Object.const_get('GeographicalAreaMembership::Operation').truncate
    Object.const_get('GoodsNomenclature::Operation').truncate
    Object.const_get('GoodsNomenclatureDescription::Operation').truncate
    Object.const_get('GoodsNomenclatureDescriptionPeriod::Operation').truncate
    Object.const_get('GoodsNomenclatureIndent::Operation').truncate
    Object.const_get('GoodsNomenclatureOrigin::Operation').truncate
    Object.const_get('GoodsNomenclatureSuccessor::Operation').truncate
    Object.const_get('Language::Operation').truncate
    Object.const_get('LanguageDescription::Operation').truncate
    Object.const_get('Measure::Operation').truncate
    Object.const_get('MeasureAction::Operation').truncate
    Object.const_get('MeasureActionDescription::Operation').truncate
    Object.const_get('MeasureComponent::Operation').truncate
    Object.const_get('MeasureCondition::Operation').truncate
    Object.const_get('MeasureConditionCode::Operation').truncate
    Object.const_get('MeasureConditionCodeDescription::Operation').truncate
    Object.const_get('MeasureConditionComponent::Operation').truncate
    Object.const_get('MeasureExcludedGeographicalArea::Operation').truncate
    Object.const_get('MeasurePartialTemporaryStop::Operation').truncate
    Object.const_get('MeasureType::Operation').truncate
    Object.const_get('MeasureTypeDescription::Operation').truncate
    Object.const_get('MeasureTypeSeries::Operation').truncate
    Object.const_get('MeasureTypeSeriesDescription::Operation').truncate
    Object.const_get('Measurement::Operation').truncate
    Object.const_get('MeasurementUnit::Operation').truncate
    Object.const_get('MeasurementUnitDescription::Operation').truncate
    Object.const_get('MeasurementUnitQualifier::Operation').truncate
    Object.const_get('MeasurementUnitQualifierDescription::Operation').truncate
    Object.const_get('MeursingAdditionalCode::Operation').truncate
    Object.const_get('MeursingHeading::Operation').truncate
    Object.const_get('MeursingHeadingText::Operation').truncate
    Object.const_get('MeursingSubheading::Operation').truncate
    Object.const_get('MeursingTableCellComponent::Operation').truncate
    Object.const_get('MeursingTablePlan::Operation').truncate
    Object.const_get('ModificationRegulation::Operation').truncate
    Object.const_get('MonetaryExchangePeriod::Operation').truncate
    Object.const_get('MonetaryExchangeRate::Operation').truncate
    Object.const_get('MonetaryUnit::Operation').truncate
    Object.const_get('MonetaryUnitDescription::Operation').truncate
    Object.const_get('ProrogationRegulation::Operation').truncate
    Object.const_get('ProrogationRegulationAction::Operation').truncate
    Object.const_get('QuotaAssociation::Operation').truncate
    Object.const_get('QuotaBalanceEvent::Operation').truncate
    Object.const_get('QuotaBlockingPeriod::Operation').truncate
    Object.const_get('QuotaClosedAndTransferredEvent::Operation').truncate
    Object.const_get('QuotaCriticalEvent::Operation').truncate
    Object.const_get('QuotaDefinition::Operation').truncate
    Object.const_get('QuotaExhaustionEvent::Operation').truncate
    Object.const_get('QuotaOrderNumber::Operation').truncate
    Object.const_get('QuotaOrderNumberOrigin::Operation').truncate
    Object.const_get('QuotaOrderNumberOriginExclusion::Operation').truncate
    Object.const_get('QuotaReopeningEvent::Operation').truncate
    Object.const_get('QuotaSuspensionPeriod::Operation').truncate
    Object.const_get('QuotaUnblockingEvent::Operation').truncate
    Object.const_get('QuotaUnsuspensionEvent::Operation').truncate
    Object.const_get('RegulationGroup::Operation').truncate
    Object.const_get('RegulationGroupDescription::Operation').truncate
    Object.const_get('RegulationReplacement::Operation').truncate
    Object.const_get('RegulationRoleType::Operation').truncate
    Object.const_get('RegulationRoleTypeDescription::Operation').truncate
    # Object.const_get('GoodsNomenclatureGroup::Operation').truncate
    # Object.const_get('GoodsNomenclatureGroupDescription::Operation').truncate
    # PublicationSigle
    # GoodsNomenclatureGroup
    # GoodsNomenclatureGroupDescription
    # ExportRefundNomenclature
    # MonetaryPlaceOfPublication
  end
end
