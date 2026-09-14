RSpec.describe CdsImporter::ExcelWriter do
  subject(:writer) { described_class.new(filename) }

  let(:filename) { 'test.xlsx' }
  let(:excel) do
    instance_double(CdsImporter::ExcelWriter::QuotaDefinition,
                    valid?: true,
                    data_row: [])
  end

  let(:excel_class) do
    class_double(CdsImporter::ExcelWriter::QuotaDefinition,
                 sheet_name: 'Sheet 1',
                 note: [],
                 heading: [],
                 table_span: [],
                 column_widths: [],
                 new: excel)
  end

  def cds_entity(key: 'K', element_id: 'E1', instance: 'I1')
    instance_double(CdsImporter::CdsEntity, key:, element_id:, instance:)
  end

  before do
    allow(Module).to receive(:const_get)
                       .with('CdsImporter::ExcelWriter::K')
                       .and_return(excel_class)

    allow(Module).to receive(:const_get)
                       .with('CdsImporter::ExcelWriter::NotExist').and_raise(NameError)
  end

  describe '#initialize' do
    it 'sets defaults and creates an excel file' do
      expect(writer.instance_variable_get(:@filename)).to eq(filename)
      expect(writer.instance_variable_get(:@xml_element_id)).to be_nil
      expect(writer.instance_variable_get(:@key)).to eq('')
      expect(writer.instance_variable_get(:@instances)).to eq([])
      expect(writer.instance_variable_get(:@workbook)).not_to be_nil
    end
  end

  describe 'process_record' do
    context 'when xml_element_id is nil' do
      it 'sets key, xml_element_id, and adds the instance' do
        writer.process_record(cds_entity)

        expect(excel_class).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
      end
    end

    context 'when xml_element_id changes' do
      it 'writes existing instances and resets before adding new one' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2', instance: 'I2'))

        expect(excel).to have_received(:data_row)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E2')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I2])
      end
    end

    context 'when xml_element_id stays the same' do
      it 'does not call write and accumulates instances' do
        entity = cds_entity
        writer.process_record(entity)
        writer.process_record(entity)

        expect(excel_class).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1 I1])
      end
    end
  end

  describe 'handle invalid cds entity' do
    it 'handles key that not mapped' do
      writer.process_record(cds_entity(key: 'NotExist', element_id: 'E2', instance: 'I2'))
      writer.process_record(cds_entity)

      expect(excel_class).not_to have_received(:sheet_name)
      expect(writer.instance_variable_get(:@key)).to eq('K')
      expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
      expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
    end
  end

  describe 'reporting failures' do
    let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
      allow(NewRelic::Agent).to receive(:notice_error)
      allow(SlackNotifierService).to receive(:call)
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      allow(TradeTariffBackend).to receive(:cds_updates_send_email).and_return(true)
      allow(TariffSynchronizer::Mailer).to receive(:cds_updates).and_return(mail)
      allow(excel_class).to receive(:sort_columns).and_return([])
    end

    context 'when writing a row raises' do
      before do
        allow(excel).to receive(:data_row).and_raise(StandardError, 'boom')
      end

      it 'logs the error' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2'))

        expect(Rails.logger).to have_received(:error).with(/write error for K in test.xlsx - boom/)
      end

      it 'records the error in New Relic' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2'))

        expect(NewRelic::Agent).to have_received(:notice_error)
      end

      it 'instruments the failure event' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2'))

        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          described_class::FAILURE_EVENT,
          hash_including(filename: 'test.xlsx'),
        )
      end

      it 'does not raise, so a data import that otherwise succeeded still completes' do
        writer.process_record(cds_entity)

        expect { writer.process_record(cds_entity(element_id: 'E2')) }.not_to raise_error
      end
    end

    context 'when one row failed but the rest of the file wrote cleanly' do
      before do
        calls = 0
        allow(excel).to receive(:data_row) do
          calls += 1
          raise StandardError, 'boom' if calls == 1

          []
        end
      end

      it 'does not email a report it knows is incomplete' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2'))
        writer.after_parse

        expect(TariffSynchronizer::Mailer).not_to have_received(:cds_updates)
      end

      it 'instruments a failure event for the report it did not send' do
        writer.process_record(cds_entity)
        writer.process_record(cds_entity(element_id: 'E2'))
        writer.after_parse

        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          described_class::FAILURE_EVENT,
          hash_including(message: /not sent/),
        )
      end
    end

    context 'when delivering the email raises' do
      before do
        allow(mail).to receive(:deliver_now).and_raise(StandardError, 'smtp down')
      end

      it 'logs the delivery failure' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(Rails.logger).to have_received(:error).with(/delivery failed.*smtp down/)
      end

      it 'instruments the failure event' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          described_class::FAILURE_EVENT,
          hash_including(message: /delivery failed/),
        )
      end
    end

    context 'when building the worksheets raises' do
      before do
        allow(excel_class).to receive(:heading).and_raise(StandardError, 'bad sheet')
      end

      it 'instruments the failure event' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          described_class::FAILURE_EVENT,
          hash_including(message: /bad sheet/),
        )
      end
    end

    context 'when a row is not valid' do
      before do
        allow(excel).to receive(:valid?).and_return(false)
      end

      it 'logs the dropped rows' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(Rails.logger).to have_received(:warn).with(/dropped 1 invalid K row/)
      end

      it 'still sends the report, because an invalid row is a deliberate filter' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(TariffSynchronizer::Mailer).to have_received(:cds_updates)
      end
    end

    context 'when everything succeeds' do
      it 'sends the report' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(TariffSynchronizer::Mailer).to have_received(:cds_updates)
      end

      it 'instruments no failure event' do
        writer.process_record(cds_entity)
        writer.after_parse

        expect(ActiveSupport::Notifications).not_to have_received(:instrument).with(
          described_class::FAILURE_EVENT,
          anything,
        )
      end
    end
  end
end
