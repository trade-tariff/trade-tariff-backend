require 'zip'

# rubocop:disable Metrics/ModuleLength
module SynchronizerHelper
  def create_taric_file(date = Time.zone.today)
    date = Date.parse(date.to_s)

    content = %(<?xml version="1.0" encoding="UTF-8"?>
      <env:envelope xmlns="urn:publicid:-:DGTAXUD:TARIC:MESSAGE:1.0" xmlns:env="urn:publicid:-:DGTAXUD:GENERAL:ENVELOPE:1.0" id="1">
        <env:transaction id="1">
          <app.message id="8">
            <transmission>
              <record>
                <transaction.id>2179611</transaction.id>
                <record.code>200</record.code>
                <subrecord.code>00</subrecord.code>
                <record.sequence.number>388</record.sequence.number>
                <update.type>3</update.type>
                <footnote>
                  <footnote.type.id>TM</footnote.type.id>
                  <footnote.id>127</footnote.id>
                  <validity.start.date>1972-01-01</validity.start.date>
                  <validity.end.date>1995-12-31</validity.end.date>
                </footnote>
              </record>
            </transmission>
          </app.message>
        </env:transaction>
      </env:envelope>)

    taric_file_path = File.join(TariffSynchronizer.root_path, 'taric', "#{date}_TGB#{date.strftime('%y')}#{date.yday.to_s.rjust(3, '0')}.xml")
    create_file taric_file_path, content
  end

  def create_cds_file(date = Time.zone.today)
    content = %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <ns2:TariffHistoryResponse xmlns:ns2="http://www.eurodyn.com/Tariff/services/DispatchDataExportXMLData/v03">
          <ResultsInfo>
              <totalRecords>1032</totalRecords>
              <executionDate>2025-10-22T00:15:30</executionDate>
              <startDate>2025-10-21T00:00:00</startDate>
              <endDate>2025-10-21T23:59:59</endDate>
          </ResultsInfo>
          <TariffHistoryItem>
          <findMeasureByDatesResponseHistory>
              <Measure>
                  <hjid>11935177</hjid>
                  <metainfo>
                      <opType>U</opType>
                      <origin>T</origin>
                      <status>L</status>
                      <transactionDate>2025-10-21T12:16:03</transactionDate>
                  </metainfo>
                  <sid>20186262</sid>
                  <justificationRegulationId>X2208010</justificationRegulationId>
                  <justificationRegulationRole>
                      <hjid>386</hjid>
                      <regulationRoleTypeId>1</regulationRoleTypeId>
                  </justificationRegulationRole>
                  <measureGeneratingRegulationId>X2208010</measureGeneratingRegulationId>
                  <measureGeneratingRegulationRole>
                      <hjid>386</hjid>
                      <regulationRoleTypeId>1</regulationRoleTypeId>
                  </measureGeneratingRegulationRole>
                  <stoppedFlag>0</stoppedFlag>
                  <validityEndDate>2025-10-31T23:59:59</validityEndDate>
                  <validityStartDate>2022-07-21T00:00:00</validityStartDate>
                  <geographicalArea>
                      <hjid>23821</hjid>
                      <sid>199</sid>
                      <geographicalAreaId>RU</geographicalAreaId>
                      <validityStartDate>1992-06-01T00:00:00</validityStartDate>
                  </geographicalArea>
                  <goodsNomenclature>
                      <hjid>11526622</hjid>
                      <sid>107463</sid>
                      <goodsNomenclatureItemId>4412510000</goodsNomenclatureItemId>
                      <produclineSuffix>80</produclineSuffix>
                      <validityStartDate>2022-01-01T00:00:00</validityStartDate>
                  </goodsNomenclature>
                  <measureType>
                      <hjid>10370727</hjid>
                      <measureTypeId>766</measureTypeId>
                  </measureType>
                  <regulationRoleType>
                      <hjid>386</hjid>
                      <regulationRoleTypeId>1</regulationRoleTypeId>
                  </regulationRoleType>
              </Measure>
          </findMeasureByDatesResponseHistory>
      </TariffHistoryItem>
    </ns2:TariffHistoryResponse>)

    date = Date.parse(date.to_s)
    filename = "tariff_dailyExtract_v1_#{date.strftime('%Y%m%d')}T123456.gzip"
    archive_path = File.join(TariffSynchronizer.root_path, 'cds', filename)

    Zip::File.open(archive_path, create: true) do |archive|
      archive.get_output_stream("#{date}_TGB#{date.strftime('%y')}#{date.yday.to_s.rjust(3, '0')}.xml") do |entry|
        entry.write content
      end
    end
  end

  def prepare_synchronizer_folders(type)
    FileUtils.mkdir_p File.join(TariffSynchronizer.root_path)
    FileUtils.mkdir_p File.join(TariffSynchronizer.root_path, type)
  end

  def purge_synchronizer_folders
    FileUtils.rm_rf(Rails.root.join(TariffSynchronizer.root_path))
  end

  def create_file(path, content = '')
    data_file = File.new(path, 'w')
    data_file.write(content)
    data_file.close
  end
end
# rubocop:enable Metrics/ModuleLength
