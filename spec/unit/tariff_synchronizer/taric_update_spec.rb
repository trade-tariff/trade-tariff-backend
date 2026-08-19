RSpec.describe TariffSynchronizer::TaricUpdate do
  let(:example_date) { Date.new(2010, 1, 1) }

  describe '.update_type' do
    it 'returns :taric' do
      expect(described_class.update_type).to eq(:taric)
    end
  end

  describe '.correct_filename_sequence?' do
    subject(:taric_update) { described_class }

    context 'when there are updates with an unbroken sequence' do
      before do
        create(:taric_update, :missing, example_date: Date.parse('2021-12-04'), sequence_number: 'foo')
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '202')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '201')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '200')
      end

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when there are updates with a broken sequence' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '200')
      end

      it { is_expected.not_to be_correct_filename_sequence }
    end

    context 'when there are no updates' do
      it { is_expected.to be_correct_filename_sequence }
    end
  end

  describe '.correct_sequence_pair?' do
    subject(:correct_sequence_pair) { described_class.correct_sequence_pair?(pending_update, applied_update) }

    let(:pending_update) { create(:taric_update, :pending, example_date: pending_date, sequence_number: pending_sequence_number) }
    let(:applied_update) { create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '002') }

    context 'when the pending year is the same and the pending sequence is the next valid sequence' do
      let(:pending_date) { Date.parse('2021-12-02') }
      let(:pending_sequence_number) { '003' }

      it { is_expected.to be_truthy }
    end

    context 'when the pending year is the same and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2021-12-02') }
      let(:pending_sequence_number) { '004' }

      it { is_expected.to be_falsey }
    end

    context 'when the pending year is the following year and the pending sequence is 001' do
      let(:pending_date) { Date.parse('2022-12-02') }
      let(:pending_sequence_number) { '001' }

      it { is_expected.to be_truthy }
    end

    context 'when the pending year is the following year and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2022-12-02') }
      let(:pending_sequence_number) { '002' }

      it { is_expected.to be_falsey }
    end
  end

  describe '#filename_sequence' do
    subject(:taric_update) { create(:taric_update, filename:) }

    let(:filename) { '2021-12-30_TGB21257.xml' }

    it 'returns the correct named captures' do
      expect(taric_update.filename_sequence.named_captures).to eq('year' => '21', 'sequence' => '257', 'url_filename' => 'TGB21257.xml')
    end
  end

  describe '#next_update_sequence_url_filename' do
    subject(:next_update_sequence_url_filename) { taric_update.next_update_sequence_url_filename }

    let(:taric_update) { create(:taric_update, filename: '2021-12-30_TGB21257.xml', issue_date:) }

    context 'when the next issue date is the same year' do
      let(:issue_date) { Date.parse('2021-12-30') }

      it { is_expected.to eq('TGB21258.xml') }
    end

    context 'when the next issue date is a new year' do
      let(:issue_date) { Date.parse('2021-12-31') }

      it { is_expected.to eq('TGB22001.xml') }
    end
  end

  describe '#next_update_sequence_update_filename' do
    subject(:next_update_sequence_update_filename) { taric_update.next_update_sequence_update_filename }

    let(:taric_update) { create(:taric_update, filename: '2021-12-30_TGB21257.xml', issue_date:) }

    context 'when the next issue date is the same year' do
      let(:issue_date) { Date.parse('2021-12-30') }

      it { is_expected.to eq('2021-12-31_TGB21258.xml') }
    end

    context 'when the next issue date is a new year' do
      let(:issue_date) { Date.parse('2021-12-31') }

      it { is_expected.to eq('2022-01-01_TGB22001.xml') }
    end
  end

  describe '#next_update' do
    subject(:next_update) { build(:taric_update, :applied, example_date: Date.parse('2022-08-25')).next_update }

    it { is_expected.to have_attributes(issue_date: Date.parse('2022-08-26'), filename: '2022-08-26_TGB22238.xml') }
  end

  describe '#next_rollover_update' do
    subject(:next_rollover_update) { build(:taric_update, :applied, example_date: Date.parse('2022-08-25')).next_rollover_update }

    it { is_expected.to have_attributes(issue_date: Date.parse('2023-01-01'), filename: '2023-01-01_TGB23001.xml') }
  end

  describe '#url_filename' do
    subject(:url_filename) { create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203').url_filename }

    it { is_expected.to eq('TGB21203.xml') }
  end
end
