RSpec.describe TariffChangesJobStatus do
  describe 'validations' do
    let(:job_status) { build :tariff_changes_job_status }

    it 'is valid with valid attributes' do
      expect(job_status).to be_valid
    end

    it 'requires operation_date' do
      job_status.operation_date = nil
      expect(job_status).not_to be_valid
    end
  end

  describe '.for_date' do
    let(:date) { Date.current }

    context 'when record exists' do
      let!(:existing_status) { create :tariff_changes_job_status, operation_date: date }

      it 'returns the existing record' do
        result = described_class.for_date(date)
        expect(result.id).to eq(existing_status.id)
        expect(result.operation_date).to eq(date)
      end
    end

    context 'when record does not exist' do
      it 'creates and returns a new record' do
        expect { described_class.for_date(date) }.to change(described_class, :count).by(1)

        result = described_class.for_date(date)
        expect(result.operation_date).to eq(date)
        expect(result.changes_generated_at).to be_nil
        expect(result.emails_sent_at).to be_nil
      end
    end

    it 'converts date-like objects to date' do
      time = Time.zone.now
      result = described_class.for_date(time)
      expect(result.operation_date).to eq(time.to_date)
    end
  end

  describe '.last_change_date' do
    context 'when there are no records with changes generated' do
      before do
        create :tariff_changes_job_status, operation_date: 3.days.ago
        create :tariff_changes_job_status, operation_date: 2.days.ago
      end

      it 'returns nil' do
        expect(described_class.last_change_date).to be_nil
      end
    end

    context 'when there are records with changes generated' do
      before do
        create :tariff_changes_job_status, :with_changes_generated, operation_date: 5.days.ago
        create :tariff_changes_job_status, :with_changes_generated, operation_date: 2.days.ago
        create :tariff_changes_job_status, :with_changes_generated, operation_date: 3.days.ago
        # Create a record without changes generated to ensure it's excluded
        create :tariff_changes_job_status, operation_date: 1.day.ago
      end

      it 'returns the most recent operation date with changes generated' do
        most_recent_date = described_class.where { changes_generated_at !~ nil }
                                          .order(Sequel.desc(:operation_date)).first.operation_date
        expect(described_class.last_change_date).to eq(most_recent_date)
      end
    end
  end

  describe '.pending_emails dataset method' do
    before do
      create :tariff_changes_job_status, operation_date: 5.days.ago
      create :tariff_changes_job_status, :pending_email, operation_date: 3.days.ago
      create :tariff_changes_job_status, :with_emails_sent, operation_date: 2.days.ago
      create :tariff_changes_job_status, :pending_email, operation_date: 4.days.ago
    end

    it 'returns operation dates with changes generated but no emails sent' do
      pending_dates = described_class.pending_emails
      expected_dates = described_class.where { changes_generated_at !~ nil }
                                      .where { emails_sent_at =~ nil }
                                      .select_map(:operation_date)

      expect(pending_dates).to match_array(expected_dates)
    end

    it 'returns dates in ascending order' do
      pending_dates = described_class.pending_emails
      expected_dates = described_class.where { changes_generated_at !~ nil }
                                      .where { emails_sent_at =~ nil }
                                      .order(:operation_date)
                                      .select_map(:operation_date)

      expect(pending_dates).to eq([
        *expected_dates,
      ])
    end

    it 'returns empty array when no pending emails' do
      described_class.where(changes_generated_at: nil).or(emails_sent_at: nil).delete

      expect(described_class.pending_emails).to be_empty
    end
  end

  describe '#mark_changes_generated!' do
    let(:job_status) { create :tariff_changes_job_status }

    it 'sets changes_generated_at to current time' do
      freeze_time do
        job_status.mark_changes_generated!

        expect(job_status.reload.changes_generated_at).to be_within(1.second).of(Time.zone.now)
      end
    end

    it 'updates the record in the database' do
      expect { job_status.mark_changes_generated! }
        .to(change { job_status.reload.changes_generated_at }
        .from(nil).to(be_within(1.second).of(Time.zone.now)))
    end

    it 'does not affect emails_sent_at' do
      expect { job_status.mark_changes_generated! }
        .not_to(change { job_status.reload.emails_sent_at })
    end
  end

  describe '#mark_emails_sent!' do
    let(:job_status) { create :tariff_changes_job_status }

    it 'sets emails_sent_at to current time' do
      freeze_time do
        job_status.mark_emails_sent!

        expect(job_status.reload.emails_sent_at).to be_within(1.second).of(Time.zone.now)
      end
    end

    it 'updates the record in the database' do
      expect { job_status.mark_emails_sent! }
        .to(change { job_status.reload.emails_sent_at }
        .from(nil).to(be_within(1.second).of(Time.zone.now)))
    end

    it 'does not affect changes_generated_at' do
      expect { job_status.mark_emails_sent! }
        .not_to(change { job_status.reload.changes_generated_at })
    end
  end

  describe 'workflow scenarios' do
    let(:job_status) { create :tariff_changes_job_status, operation_date: Date.current }

    context 'when testing complete workflow' do
      it 'progresses through states correctly' do
        # Initial state
        expect(job_status.changes_generated_at).to be_nil
        expect(job_status.emails_sent_at).to be_nil
        expect(described_class.pending_emails).to be_empty

        # Mark changes as generated
        job_status.mark_changes_generated!
        job_status.reload

        expect(job_status.changes_generated_at).to be_present
        expect(job_status.emails_sent_at).to be_nil
        expect(described_class.pending_emails).to include(job_status.operation_date)

        # Mark emails as sent
        job_status.mark_emails_sent!
        job_status.reload

        expect(job_status.changes_generated_at).to be_present
        expect(job_status.emails_sent_at).to be_present
        expect(described_class.pending_emails).not_to include(job_status.operation_date)
      end
    end

    context 'with multiple job statuses with different states' do
      before do
        create :tariff_changes_job_status, operation_date: 3.days.ago
        create :tariff_changes_job_status, :pending_email, operation_date: 2.days.ago
        create :tariff_changes_job_status, :with_emails_sent, operation_date: 1.day.ago
      end

      it 'correctly identifies pending emails' do
        pending_dates = described_class.pending_emails
        expected_pending = described_class.where { changes_generated_at !~ nil }
                                          .where { emails_sent_at =~ nil }
                                          .select_map(:operation_date)
        expect(pending_dates).to match_array(expected_pending)
      end

      it 'correctly identifies last change date' do
        last_change = described_class.where { changes_generated_at !~ nil }
                                     .order(Sequel.desc(:operation_date)).first.operation_date
        expect(described_class.last_change_date).to eq(last_change)
      end
    end
  end
end
