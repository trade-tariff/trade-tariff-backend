RSpec.describe SearchReferences::ChangeSource do
  describe '.label and .admin_user?' do
    {
      'ClearInvalidSearchReferences' => ['Automatic clean-up', false],
      'ClearInvalidSearchReferences (backfill)' => ['Automatic clean-up (backfill)', false],
      'fpo_csv_import' => ['FPO CSV import', false],
      '11111111-1111-4111-8111-111111111111' => ['Admin user', true],
      'basic_auth_user' => ['Admin user', true],
      'Unknown' => ['Unknown', false],
      'some_other_job' => ['some_other_job', false],
    }.each do |whodunnit, (label, admin_user)|
      context "when the whodunnit is #{whodunnit}" do
        it { expect(described_class.label(whodunnit)).to eq(label) }
        it { expect(described_class.admin_user?(whodunnit)).to be(admin_user) }
      end
    end
  end

  describe '.automatic_removal?' do
    it { expect(described_class.automatic_removal?('ClearInvalidSearchReferences')).to be(true) }
    it { expect(described_class.automatic_removal?('ClearInvalidSearchReferences (backfill)')).to be(true) }
    it { expect(described_class.automatic_removal?('11111111-1111-4111-8111-111111111111')).to be(false) }
  end

  describe 'BACKFILL_WHODUNNIT' do
    it 'matches the value the backfill rake task writes' do
      expect(described_class::BACKFILL_WHODUNNIT).to eq(SearchReferencesTasks::BACKFILL_WHODUNNIT)
    end
  end
end
