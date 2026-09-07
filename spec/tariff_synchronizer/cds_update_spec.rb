RSpec.describe TariffSynchronizer::CdsUpdate do
  let(:example_date) { Date.new(2020, 10, 10) }

  describe '.update_type' do
    it 'returns :cds' do
      expect(described_class.update_type).to eq(:cds)
    end
  end

  describe '.correct_filename_sequence?' do
    subject(:cds_update) { described_class }

    before do
      create(:cds_update, :applied, example_date: applied_date)
      create(:cds_update, :pending, example_date: pending_date)
    end

    let(:applied_date) { Time.zone.yesterday }

    context 'when the sequence date is correct' do
      let(:pending_date) { applied_date + 1.day }

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when the sequence date is incorrect' do
      let(:pending_date) { applied_date + 2.days }

      it { is_expected.not_to be_correct_filename_sequence }
    end
  end

  describe '#filename_sequence' do
    subject(:cds_update) { create(:cds_update, filename:) }

    let(:filename) { 'tariff_dailyExtract_v1_20220118T235959.gzip' }

    it 'returns the sequence date' do
      expect(cds_update.filename_sequence).to eq Date.new(2022, 0o1, 18)
    end
  end
end
