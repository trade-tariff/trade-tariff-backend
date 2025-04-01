RSpec.describe MeasurementUnit do
  subject(:measurement_unit) { create :measurement_unit, :with_description }

  describe '#to_s' do
    it 'is an alias for description' do
      expect(measurement_unit.to_s).to eq measurement_unit.description
    end
  end

  describe '#abbreviation' do
    it { expect(measurement_unit.abbreviation).to eq(measurement_unit.description) }
  end

  describe '#measurement_unit_abbreviation' do
    context 'with measurement_unit_abbreviation' do
      let!(:measurement_unit_abbreviation) do
        create(:measurement_unit_abbreviation, measurement_unit_code: measurement_unit.measurement_unit_code)
      end

      it { expect(measurement_unit.measurement_unit_abbreviation).to eq(measurement_unit_abbreviation) }
    end
  end

  describe '#expansion' do
    context 'with measurement_unit_code' do
      subject(:measurement_unit) { create :measurement_unit, :with_description, measurement_unit_code: 'ASV' }

      it { expect(measurement_unit.expansion).to eq('percentage ABV (% vol)') }
    end

    context 'with measurement_unit_code and measurement_unit_qualifier_code' do
      subject(:measurement_unit) { create :measurement_unit, :with_description, measurement_unit_code: 'ASV' }

      let(:measurement_unit_qualifier) { create(:measurement_unit_qualifier, measurement_unit_qualifier_code: 'X') }

      it { expect(measurement_unit.expansion(measurement_unit_qualifier:)).to eq('percentage ABV (% vol) per 100 litre (hl)') }
    end
  end

  describe '.units' do
    context 'with a single measurement unit' do
      subject(:result) { described_class.units('ASV', 'ASV') }

      it { is_expected.to include_json([{ 'unit' => 'percent' }]) }
    end

    context 'with a compound measurement unit' do
      subject(:result) { described_class.units('ASV', 'ASVX') }

      it { is_expected.to include_json([{ 'unit' => 'percent' }, { 'unit' => 'litres' }]) }
    end

    context 'with a compound measurement unit where one is only in the file' do
      subject(:result) { described_class.units('DTN', 'DTNZ') }

      it { is_expected.to include_json([{ 'unit' => 'kilograms' }, { 'unit' => '% sucrose' }]) }
    end

    context 'with missing measurement unit present in database' do
      subject(:result) { described_class.units('ASV', 'ASVX') }

      before do
        measurement_unit
        allow(NewRelic::Agent).to receive(:notice_error).and_call_original
        allow(described_class).to receive(:measurement_units).and_return({})
        result
      end

      let(:measurement_unit) do
        create(
          :measurement_unit,
          :with_description,
          measurement_unit_code: 'ASV',
        )
      end

      let(:expected_units) do
        [
          {
            'abbreviation' => measurement_unit.abbreviation,
            'measurement_unit_code' => 'ASV',
            'measurement_unit_qualifier_code' => 'X',
            'unit' => nil,
            'unit_hint' => "Please correctly enter unit: #{measurement_unit.description}",
            'unit_question' => "Please enter unit: #{measurement_unit.description}",
          },
        ]
      end

      it { is_expected.to eq(expected_units) }
      it { expect(NewRelic::Agent).to have_received(:notice_error) }
    end

    context 'with measurement unit not in the database' do
      subject(:result) { described_class.units('FC1', 'FC1X') }

      before do
        allow(NewRelic::Agent).to receive(:notice_error).and_call_original
        allow(described_class).to receive(:measurement_units).and_return({})
        result
      end

      let(:expected_units) do
        [
          {
            'abbreviation' => nil,
            'measurement_unit_code' => 'FC1',
            'measurement_unit_qualifier_code' => 'X',
            'unit' => nil,
            'unit_hint' => 'Please correctly enter unit: FC1',
            'unit_question' => 'Please enter unit: FC1',
          },
        ]
      end

      it { is_expected.to eq(expected_units) }
      it { expect(NewRelic::Agent).to have_received(:notice_error) }
    end
  end

  describe '.type_for' do
    subject { described_class.type_for('LTR') }

    it { is_expected.to eq('volume') }
  end

  describe '.coerced_unit_for' do
    subject { described_class.coerced_unit_for('DTN') }

    it { is_expected.to eq('KGM') }
  end

  describe '.coerced_units' do
    subject { described_class.coerced_units }

    let(:expected_units) do
      {
        'DTN' => 'KGM',
        'DTNE' => 'KGM',
        'DTNF' => 'KGM',
        'DTNG' => 'KGM',
        'DTNL' => 'KGM',
        'DTNM' => 'KGM',
        'DTNR' => 'KGM',
        'DTNS' => 'KGM',
        'HLT' => 'LTR',
        'KLT' => 'LTR',
        'TNE' => 'KGM',
        'TNEE' => 'KGM',
        'TNEI' => 'KGM',
        'TNEJ' => 'KGM',
        'TNEK' => 'KGM',
        'TNEM' => 'KGM',
        'TNER' => 'KGM',
        'TNEZ' => 'KGM',
      }
    end

    it { is_expected.to eq(expected_units) }
  end

  describe '.weight_units' do
    subject { described_class.weight_units.to_a }

    it { is_expected.to eq(%w[CCT CTM DAP DHS DTN DTNE DTNF DTNG DTNL DTNM DTNR DTNS GFI GRM GRT KCC KCL KGM KGMA KGME KGMG KGMP KGMS KGMT KMA KNI KNS KPH KPO KPP KSD KSH KUR TNE TNEE TNEI TNEJ TNEK TNEM TNER TNEZ]) }
  end

  describe '.volume_units' do
    subject { described_class.volume_units.to_a }

    it { is_expected.to eq(%w[HLT KLT LPA LTR LTRA MTQ MTQC]) }
  end

  describe '.percentage_abv_units' do
    subject { described_class.percentage_abv_units.to_a }

    it { is_expected.to eq(%w[ASV]) }
  end
end
