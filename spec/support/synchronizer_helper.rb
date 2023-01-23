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

  def prepare_synchronizer_folders
    FileUtils.mkdir_p File.join(TariffSynchronizer.root_path)
    FileUtils.mkdir_p File.join(TariffSynchronizer.root_path, 'taric')
    FileUtils.mkdir_p File.join(TariffSynchronizer.root_path, 'chief')
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
