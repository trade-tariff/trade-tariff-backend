require 'rails_helper'

RSpec.describe ActionLogReportWorker do
  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:yesterday) { Time.zone.yesterday }
    let(:start_date) { yesterday.beginning_of_day }
    let(:end_date) { yesterday.end_of_day }

    context 'when there are action logs from yesterday' do
      let(:user) { create(:public_user) }
      let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

      before do
        # Create action logs within the time range
        create(:action_log, user: user, action: PublicUsers::ActionLog::REGISTERED, created_at: start_date + 2.hours)
        create(:action_log, user: user, action: PublicUsers::ActionLog::SUBSCRIBED, created_at: start_date + 4.hours)

        # Create an action log outside of the time range
        create(:action_log, user: user, action: PublicUsers::ActionLog::DELETED, created_at: start_date - 1.day)

        allow(ActionLogMailer).to receive(:daily_report).and_return(mailer)
      end

      it 'generates CSV and sends an email with the correct data', :aggregate_failures do
        worker.perform

        expect(ActionLogMailer).to have_received(:daily_report) do |csv_data, date|
          expect(date).to eq(yesterday.strftime('%Y-%m-%d'))
          expect(csv_data).to include('ID,User ID,Action,Created At')
          expect(csv_data).to include(PublicUsers::ActionLog::REGISTERED)
          expect(csv_data).to include(PublicUsers::ActionLog::SUBSCRIBED)
          expect(csv_data).not_to include(PublicUsers::ActionLog::DELETED)
        end

        expect(mailer).to have_received(:deliver_now)
      end
    end

    context 'when there are no action logs from yesterday' do
      before do
        # Create an action log outside of the time range
        create(:action_log, action: PublicUsers::ActionLog::REGISTERED, created_at: start_date - 1.day)

        allow(ActionLogMailer).to receive(:daily_report)
      end

      it 'does not send an email' do
        worker.perform

        expect(ActionLogMailer).not_to have_received(:daily_report)
      end
    end
  end
end
