# rubocop:disable RSpec/DescribeClass, RSpec/MultipleDescribes
require 'zip'

RSpec.describe 'tariff:sync:status' do
  after { Rake::Task['tariff:sync:status'].reenable }

  context 'with a mix of update states' do
    let!(:applied_cds) { create(:cds_update, :applied, issue_date: 2.days.ago.to_date) }
    let!(:pending_cds) { create(:cds_update, :pending, issue_date: 1.day.ago.to_date) }
    let!(:failed_cds) do
      create(:cds_update, :failed, issue_date: Date.current, exception_class: 'Sequel::DatabaseError: bad record')
    end

    let(:output) do
      original_stdout = $stdout
      $stdout = StringIO.new
      Rake::Task['tariff:sync:status'].invoke
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    before do
      create(:taric_update, :applied, issue_date: 2.days.ago.to_date)
      create(:taric_update, :pending, issue_date: 1.day.ago.to_date)
      allow(TariffSynchronizer::CdsUpdate).to receive(:correct_filename_sequence?).and_return(true)
      allow(TariffSynchronizer::TaricUpdate).to receive(:correct_filename_sequence?).and_return(false)
    end

    it 'shows both service sections', :aggregate_failures do
      expect(output).to match(/UK \(CDS\)/)
      expect(output).to match(/XI \(TARIC\)/)
    end

    it 'shows the last applied CDS filename' do
      expect(output).to include(applied_cds.filename)
    end

    it 'shows pending CDS filename' do
      expect(output).to include(pending_cds.filename)
    end

    it 'shows failed CDS filename and error class', :aggregate_failures do
      expect(output).to include(failed_cds.filename)
      expect(output).to match(/Sequel::DatabaseError/)
    end

    it 'shows OK sequence for CDS and INVALID for TARIC', :aggregate_failures do
      expect(output).to match(/Sequence\s+: OK/)
      expect(output).to match(/Sequence\s+: INVALID/)
    end
  end

  context 'with no updates' do
    before do
      allow(TariffSynchronizer::CdsUpdate).to receive(:correct_filename_sequence?).and_return(true)
      allow(TariffSynchronizer::TaricUpdate).to receive(:correct_filename_sequence?).and_return(true)
    end

    it 'shows none for last applied' do
      expect { Rake::Task['tariff:sync:status'].invoke }
        .to output(/Last applied\s+: none/).to_stdout
    end
  end
end

RSpec.describe 'tariff:sync:failures' do
  after { Rake::Task['tariff:sync:failures'].reenable }

  context 'with no failed updates' do
    it 'reports no failures' do
      expect { Rake::Task['tariff:sync:failures'].invoke }
        .to output(/No failed updates/).to_stdout
    end
  end

  context 'with a failed CDS update' do
    let!(:failed_cds) do
      create(:cds_update, :failed,
             issue_date: Date.current,
             exception_class: 'Sequel::DatabaseError: constraint violation')
    end

    let(:output) do
      original_stdout = $stdout
      $stdout = StringIO.new
      Rake::Task['tariff:sync:failures'].invoke
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    it 'lists the filename and service', :aggregate_failures do
      expect(output).to include(failed_cds.filename)
      expect(output).to include('UK/CDS')
    end

    it 'shows the error class' do
      expect(output).to match(/Sequel::DatabaseError/)
    end

    it 'shows the CDS error count when present' do
      TariffSynchronizer::TariffUpdateCdsError.create(
        tariff_update_filename: failed_cds.filename,
        model_name: 'Measure',
        details: { errors: %w[invalid] },
      )

      expect(output).to match(/CDS errors\s+: 1/)
    end

    it 'suggests running failure_detail' do
      expect(output).to include('failure_detail')
    end
  end

  context 'with a failed TARIC update' do
    let!(:failed_taric) { create(:taric_update, :failed, issue_date: Date.current) }

    it 'shows XI/TARIC as the service' do
      expect { Rake::Task['tariff:sync:failures'].invoke }
        .to output(/XI\/TARIC/).to_stdout
    end

    it 'shows the presence error count when present' do
      TariffSynchronizer::TariffUpdatePresenceError.create(
        tariff_update_filename: failed_taric.filename,
        model_name: 'GoodsNomenclature',
        details: { some: 'detail' },
      )

      expect { Rake::Task['tariff:sync:failures'].invoke }
        .to output(/Presence errors\s+: 1/).to_stdout
    end
  end
end

RSpec.describe 'tariff:sync:failure_detail' do
  after do
    Rake::Task['tariff:sync:failure_detail'].reenable
    ENV.delete('FILENAME')
  end

  context 'without FILENAME set' do
    it 'aborts with an instruction' do
      expect { Rake::Task['tariff:sync:failure_detail'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with an unknown filename' do
    before { ENV['FILENAME'] = 'nonexistent.gzip' }

    it 'aborts' do
      expect { Rake::Task['tariff:sync:failure_detail'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with a failed CDS update' do
    let!(:update) do
      create(:cds_update, :failed,
             filesize: 12_345,
             exception_class: 'Sequel::DatabaseError: bad column',
             exception_backtrace: "line 1\nline 2\nline 3",
             exception_queries: 'SELECT * FROM measures',
             inserts: { operations: {}, total_count: 0 }.to_json)
    end

    let(:output) do
      original_stdout = $stdout
      $stdout = StringIO.new
      Rake::Task['tariff:sync:failure_detail'].invoke
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    before { ENV['FILENAME'] = update.filename }

    it 'shows the service, state and issue date', :aggregate_failures do
      expect(output).to match(/UK \(CDS\)/)
      expect(output).to match(/State\s+: F/)
      expect(output).to match(/Issue date\s+: #{update.issue_date}/)
    end

    it 'shows the file size' do
      expect(output).to match(/12345 bytes/)
    end

    it 'shows the exception class' do
      expect(output).to match(/Sequel::DatabaseError: bad column/)
    end

    it 'shows the backtrace', :aggregate_failures do
      expect(output).to match(/line 1/)
      expect(output).to match(/line 2/)
    end

    it 'shows the last SQL queries' do
      expect(output).to match(/SELECT \* FROM measures/)
    end

    it 'shows the previous import operation counts' do
      expect(output).to match(/total_count/)
    end

    context 'with associated CDS errors' do
      before do
        TariffSynchronizer::TariffUpdateCdsError.create(
          tariff_update_filename: update.filename,
          model_name: 'Measure',
          details: { errors: ['is invalid'], xml_node: '<Measure/>' },
        )
      end

      it 'shows CDS errors with model name and details', :aggregate_failures do
        expect(output).to match(/CDS Record Errors/)
        expect(output).to match(/Measure/)
        expect(output).to match(/is invalid/)
      end
    end
  end

  context 'with a failed TARIC update' do
    let!(:update) { create(:taric_update, :failed) }

    before { ENV['FILENAME'] = update.filename }

    it 'shows XI (TARIC) as the service' do
      expect { Rake::Task['tariff:sync:failure_detail'].invoke }
        .to output(/XI \(TARIC\)/).to_stdout
    end

    context 'with associated presence errors' do
      let(:output) do
        original_stdout = $stdout
        $stdout = StringIO.new
        Rake::Task['tariff:sync:failure_detail'].invoke
        $stdout.string
      ensure
        $stdout = original_stdout
      end

      before do
        TariffSynchronizer::TariffUpdatePresenceError.create(
          tariff_update_filename: update.filename,
          model_name: 'GoodsNomenclature',
          details: { some: 'detail' },
        )
      end

      it 'shows presence errors with model name', :aggregate_failures do
        expect(output).to match(/Presence Errors/)
        expect(output).to match(/GoodsNomenclature/)
      end
    end
  end
end

RSpec.describe 'tariff:sync:inspect_file' do
  after do
    Rake::Task['tariff:sync:inspect_file'].reenable
    ENV.delete('FILENAME')
  end

  context 'without FILENAME set' do
    it 'aborts with an instruction' do
      expect { Rake::Task['tariff:sync:inspect_file'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with an unknown filename' do
    before { ENV['FILENAME'] = 'nonexistent.gzip' }

    it 'aborts' do
      expect { Rake::Task['tariff:sync:inspect_file'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with a CDS update whose file is not found' do
    let!(:update) { create(:cds_update, :pending) }

    before do
      ENV['FILENAME'] = update.filename
      allow(TariffSynchronizer::FileService).to receive(:file_exists?).and_return(false)
    end

    it 'aborts' do
      expect { Rake::Task['tariff:sync:inspect_file'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with a pending CDS update' do
    let!(:update) { create(:cds_update, :pending) }

    let(:empty_zip) do
      Zip::OutputStream.write_buffer { |zip|
        zip.put_next_entry('data.xml')
        zip.write('<root><level1><level2/></level1></root>')
      }.tap(&:rewind)
    end

    let(:output) do
      original_stdout = $stdout
      $stdout = StringIO.new
      Rake::Task['tariff:sync:inspect_file'].invoke
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    before do
      ENV['FILENAME'] = update.filename
      allow(TariffSynchronizer::FileService).to receive_messages(file_exists?: true, file_size: 4096)
      allow(TariffSynchronizer::FileService).to receive(:file_as_stringio).with(update).and_return(empty_zip)
    end

    it 'shows the file header with state and size', :aggregate_failures do
      expect(output).to match(/State\s+: P/)
      expect(output).to match(/4096 bytes/)
    end

    it 'shows the entity record summary' do
      expect(output).to match(/Total entity records:/)
    end
  end

  context 'with a pending TARIC update' do
    let!(:update) { create(:taric_update, :pending) }

    let(:taric_xml) do
      StringIO.new(<<~XML)
        <envelope>
          <record><GoodsNomenclature/></record>
          <record><GoodsNomenclature/></record>
          <record><Measure/></record>
        </envelope>
      XML
    end

    let(:output) do
      original_stdout = $stdout
      $stdout = StringIO.new
      Rake::Task['tariff:sync:inspect_file'].invoke
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    before do
      ENV['FILENAME'] = update.filename
      allow(TariffSynchronizer::FileService).to receive_messages(file_exists?: true, file_size: 2048)
      allow(TariffSynchronizer::FileService).to receive(:get).with(update.file_path).and_return(taric_xml)
    end

    it 'shows the file header', :aggregate_failures do
      expect(output).to match(/State\s+: P/)
      expect(output).to match(/2048 bytes/)
    end

    it 'shows the transaction record summary with counts', :aggregate_failures do
      expect(output).to match(/Total transaction records: 3/)
      expect(output).to match(/GoodsNomenclature\s+2/)
      expect(output).to match(/Measure\s+1/)
    end
  end
end

RSpec.describe 'tariff:sync:reset_failed' do
  after { Rake::Task['tariff:sync:reset_failed'].reenable }

  context 'with no failed updates' do
    it 'reports nothing to reset' do
      expect { Rake::Task['tariff:sync:reset_failed'].invoke }
        .to output(/No failed updates to reset/).to_stdout
    end
  end

  context 'with failed updates' do
    let!(:failed_cds) do
      create(:cds_update, :failed,
             exception_class: 'SomeError',
             exception_backtrace: 'backtrace',
             exception_queries: 'SELECT 1')
    end
    let!(:failed_taric) { create(:taric_update, :failed, exception_class: 'OtherError') }

    it 'resets all failed updates to pending', :aggregate_failures do
      suppress_output { Rake::Task['tariff:sync:reset_failed'].invoke }

      expect(failed_cds.reload.state).to eq('P')
      expect(failed_taric.reload.state).to eq('P')
    end

    it 'clears exception fields', :aggregate_failures do
      suppress_output { Rake::Task['tariff:sync:reset_failed'].invoke }

      reloaded = failed_cds.reload
      expect(reloaded.exception_class).to be_nil
      expect(reloaded.exception_backtrace).to be_nil
      expect(reloaded.exception_queries).to be_nil
    end

    it 'reports how many were reset' do
      expect { Rake::Task['tariff:sync:reset_failed'].invoke }
        .to output(/2 update\(s\) reset to pending/).to_stdout
    end

    it 'suggests running apply next' do
      expect { Rake::Task['tariff:sync:reset_failed'].invoke }
        .to output(/tariff:sync:apply/).to_stdout
    end
  end
end

RSpec.describe 'tariff:sync:force_apply' do
  after do
    Rake::Task['tariff:sync:force_apply'].reenable
    ENV.delete('FILENAME')
    ENV.delete('CONFIRM')
  end

  context 'without FILENAME set' do
    it 'aborts' do
      expect { Rake::Task['tariff:sync:force_apply'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with FILENAME but without CONFIRM=yes' do
    let!(:update) { create(:cds_update, :failed) }

    before { ENV['FILENAME'] = update.filename }

    it 'exits without applying' do
      expect { Rake::Task['tariff:sync:force_apply'].invoke }
        .to raise_error(SystemExit)
    end

    it 'warns about data loss' do
      expect { Rake::Task['tariff:sync:force_apply'].invoke }
        .to output(/WITHOUT importing its data/).to_stderr
    rescue SystemExit
      nil
    end

    it 'does not change the update state' do
      suppress_output { Rake::Task['tariff:sync:force_apply'].invoke }
    rescue SystemExit
      expect(update.reload.state).to eq('F')
    end
  end

  context 'with CONFIRM=yes against a non-failed update' do
    let!(:update) { create(:cds_update, :pending) }

    before do
      ENV['FILENAME'] = update.filename
      ENV['CONFIRM']  = 'yes'
    end

    it 'aborts with a state error' do
      expect { Rake::Task['tariff:sync:force_apply'].invoke }
        .to raise_error(SystemExit)
    end
  end

  context 'with CONFIRM=yes against a failed update' do
    let!(:update) { create(:cds_update, :failed) }

    before do
      ENV['FILENAME'] = update.filename
      ENV['CONFIRM']  = 'yes'
    end

    it 'marks the update as applied' do
      suppress_output { Rake::Task['tariff:sync:force_apply'].invoke }

      expect(update.reload.state).to eq('A')
    end

    it 'sets applied_at' do
      suppress_output { Rake::Task['tariff:sync:force_apply'].invoke }

      expect(update.reload.applied_at).to be_present
    end

    it 'confirms the action in output' do
      expect { Rake::Task['tariff:sync:force_apply'].invoke }
        .to output(/marked as applied/).to_stdout
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/MultipleDescribes
