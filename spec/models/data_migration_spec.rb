RSpec.describe DataMigration do
  describe '.for_version' do
    subject(:count) { described_class.version(version).count }

    before do
      described_class.unrestrict_primary_key
      described_class.create(filename: '20220401000000_test_record.rb')
    end

    context 'with valid version' do
      let(:version) { '20220401000000' }

      it { is_expected.to be 1 }
    end

    context 'with invalid version' do
      let(:version) { '20220401' }

      it { expect { count }.to raise_error ArgumentError, 'Invalid version number' }
    end
  end

  describe '.since' do
    subject(:count) { described_class.since(since).pluck(:filename) }

    let(:since) { Time.zone.parse '2022-04-10' }

    before do
      described_class.unrestrict_primary_key
      described_class.create(filename: '20220501000000_second.rb')
      described_class.create(filename: '20220601000000_third.rb')
      described_class.create(filename: '20220401000000_test.rb')
    end

    it { is_expected.not_to include '20220401000000_test.rb' }
    it { is_expected.to include '20220501000000_second.rb' }
    it { is_expected.to include '20220601000000_third.rb' }
  end

  describe '.upto' do
    subject(:count) { described_class.upto(upto).pluck(:filename) }

    let(:upto) { Time.zone.parse '2022-05-10' }

    before do
      described_class.unrestrict_primary_key
      described_class.create(filename: '20220501000000_second.rb')
      described_class.create(filename: '20220601000000_third.rb')
      described_class.create(filename: '20220401000000_test.rb')
    end

    it { is_expected.to include '20220401000000_test.rb' }
    it { is_expected.to include '20220501000000_second.rb' }
    it { is_expected.not_to include '20220601000000_third.rb' }
  end

  describe 'within' do
    subject(:count) { described_class.within(since, upto).pluck(:filename) }

    let(:since) { Time.zone.parse '2022-04-10' }
    let(:upto) { Time.zone.parse '2022-05-10' }

    before do
      described_class.unrestrict_primary_key
      described_class.create(filename: '20220501000000_second.rb')
      described_class.create(filename: '20220601000000_third.rb')
      described_class.create(filename: '20220401000000_test.rb')
    end

    it { is_expected.not_to include '20220401000000_test.rb' }
    it { is_expected.to include '20220501000000_second.rb' }
    it { is_expected.not_to include '20220601000000_third.rb' }
  end
end
