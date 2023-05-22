RSpec.describe SimplifiedProceduralCodeMeasure do
  describe '.by_spv' do
    subject(:by_spv) { described_class.by_spv(simplified_procedural_code) }

    before do
      create :measure, :simplified_procedural_code, simplified_procedural_code: '123'
      create :measure, :simplified_procedural_code, simplified_procedural_code: '456'
    end

    context 'when there is a matching record' do
      let(:simplified_procedural_code) { '123' }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { is_expected.to all(have_attributes(simplified_procedural_code: '123')) }
    end

    context 'when there is no matching record' do
      let(:simplified_procedural_code) { '789' }

      it { is_expected.to be_empty }
    end

    context 'when the input code is blank' do
      let(:simplified_procedural_code) { '' }

      it { is_expected.to have_attributes(count: 2) }
      it { is_expected.to all(be_a(described_class)) }
    end
  end

  describe '.from_date' do
    subject(:from_date) { described_class.from_date(date) }

    before do
      create :measure, :simplified_procedural_code, validity_start_date: Date.new(2022, 1, 1)
    end

    context 'when the from date is before the validity start date' do
      let(:date) { Date.new(2021, 12, 31) }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { expect(from_date.map(&:validity_start_date)).to all(eq Date.new(2022, 1, 1)) }
    end

    context 'when the from date is the same as the validity start date' do
      let(:date) { Date.new(2022, 1, 1) }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { expect(from_date.map(&:validity_start_date)).to all(eq Date.new(2022, 1, 1)) }
    end

    context 'when the from date is after the validity start date' do
      let(:date) { Date.new(2022, 1, 2) }

      it { is_expected.to be_empty }
    end
  end

  describe '.to_date' do
    subject(:to_date) { described_class.to_date(date) }

    before do
      create :measure, :simplified_procedural_code, validity_end_date: Date.new(2022, 1, 1)
      create :measure, :simplified_procedural_code, validity_end_date: Date.new(2022, 1, 2)
    end

    context 'when the to date is before the validity end date' do
      let(:date) { Date.new(2022, 1, 1) }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { is_expected.to all(have_attributes(validity_end_date: Date.new(2022, 1, 1))) }
    end

    context 'when the to date is the same as the validity end date' do
      let(:date) { Date.new(2022, 1, 2) }

      it { is_expected.to have_attributes(count: 2) }
      it { is_expected.to all(be_a(described_class)) }
      it { expect(to_date.map(&:validity_end_date)).to all(be <= date) }
    end

    context 'when the to date is after the validity end date' do
      let(:date) { Date.new(2022, 1, 3) }

      it { is_expected.to have_attributes(count: 2) }
      it { is_expected.to all(be_a(described_class)) }
    end
  end
end
