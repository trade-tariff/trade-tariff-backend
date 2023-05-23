RSpec.describe SimplifiedProceduralCodeMeasure do
  describe '.with_filter' do
    subject(:with_filter) { described_class.with_filter(filters) }

    before do
      create :measure, :simplified_procedural_code, simplified_procedural_code: '123', validity_start_date: Date.new(2022, 1, 1), validity_end_date: Date.new(2022, 1, 2)
    end

    context 'when there are no filters' do
      let(:filters) { {} }

      it { is_expected.to have_attributes(count: 1) }
    end

    context 'when there is a from date' do
      let(:filters) { { from_date: Date.new(2021, 12, 31) } }

      it { is_expected.to have_attributes(count: 1) }
    end

    context 'when there is a to date' do
      let(:filters) { { to_date: Date.new(2022, 1, 2) } }

      it { is_expected.to have_attributes(count: 1) }
    end

    context 'when there is a simplified procedural code' do
      let(:filters) { { simplified_procedural_code: '123' } }

      it { is_expected.to have_attributes(count: 1) }
    end

    context 'when there is a from date and a to date' do
      let(:filters) { { from_date: Date.new(2021, 12, 31), to_date: Date.new(2022, 1, 2) } }

      it { is_expected.to have_attributes(count: 1) }
    end
  end

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
    end

    context 'when the to date is before the validity end date' do
      let(:date) { Date.new(2021, 12, 31) }

      it { is_expected.to be_empty }
    end

    context 'when the to date is the same as the validity end date' do
      let(:date) { Date.new(2022, 1, 1) }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { expect(to_date.map(&:validity_end_date)).to all(eq Date.new(2022, 1, 1)) }
    end

    context 'when the to date is after the validity end date' do
      let(:date) { Date.new(2022, 1, 3) }

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(be_a(described_class)) }
      it { expect(to_date.map(&:validity_end_date)).to all(eq Date.new(2022, 1, 1)) }
    end
  end
end
