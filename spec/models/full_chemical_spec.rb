RSpec.describe FullChemical do
  describe '#goods_nomenclature' do
    subject(:goods_nomenclature) { create(:full_chemical).goods_nomenclature }

    it { is_expected.to be_a(GoodsNomenclature) }
  end

  describe 'validations' do
    subject(:errors) { described_class.new.tap(&:valid?).errors }

    it { is_expected.to include(goods_nomenclature_sid: ['is not present']) }
    it { is_expected.to include(goods_nomenclature_item_id: ['is not present']) }
    it { is_expected.to include(producline_suffix: ['is not present']) }
    it { is_expected.to include(name: ['is not present']) }
  end

  describe 'dataset methods' do
    describe '.with_filter' do
      subject(:full_chemicals) { described_class.with_filter(filters) }

      context 'when all the filters are provided' do
        before do
          create(:full_chemical, goods_nomenclature_sid: 999_999_998) # varying sids
          create(:full_chemical, goods_nomenclature_sid: 999_999_999) # varying sids
          create(:full_chemical, goods_nomenclature_item_id: '0409000000') # varying codes
          create(:full_chemical, goods_nomenclature_item_id: '0409000001') # varying codes
          create(:full_chemical, producline_suffix: '80') # varying suffixes
          create(:full_chemical, producline_suffix: '81') # varying suffixes
          create(:full_chemical, cus: '1234567890') # varying cus
          create(:full_chemical, cus: '1234567891') # varying cus
          create(:full_chemical, cas_rn: '1234567890') # varying cas_rns
          create(:full_chemical, cas_rn: '1234567891') # varying cas_rns
        end

        let(:filters) do
          full_chemical = described_class.first

          {
            goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
            goods_nomenclature_item_id: full_chemical.goods_nomenclature_item_id,
            producline_suffix: full_chemical.producline_suffix,
            cus: full_chemical.cus,
            cas_rn: full_chemical.cas_rn,
          }
        end

        it { is_expected.to eq([described_class.first.reload]) }
      end

      context 'when a goods_nomenclature_sid filter is provided' do
        subject(:full_chemicals) { described_class.with_filter(goods_nomenclature_sid: 999_999_999) }

        before do
          create(:full_chemical, goods_nomenclature_sid: 999_999_998) # varying sids
          create(:full_chemical, goods_nomenclature_sid: 999_999_999) # varying sids
        end

        let(:expected_chemical) { described_class.where(goods_nomenclature_sid: 999_999_999).take }

        it { is_expected.to eq([expected_chemical]) }
      end

      context 'when a goods_nomenclature_item_id filter is provided' do
        subject(:full_chemicals) { described_class.with_filter(goods_nomenclature_item_id: '0409000000') }

        before do
          create(:full_chemical, goods_nomenclature_item_id: '0409000000') # varying codes
          create(:full_chemical, goods_nomenclature_item_id: '0409000001') # varying codes
        end

        let(:expected_chemical) { described_class.where(goods_nomenclature_item_id: '0409000000').take }

        it { is_expected.to eq([expected_chemical]) }
      end

      context 'when a producline_suffix filter is provided' do
        subject(:full_chemicals) { described_class.with_filter(producline_suffix: '80') }

        before do
          create(:full_chemical, producline_suffix: '80') # varying suffixes
          create(:full_chemical, producline_suffix: '81') # varying suffixes
        end

        let(:expected_chemical) { described_class.where(producline_suffix: '80').take }

        it { is_expected.to eq([expected_chemical]) }
      end

      context 'when a cus filter is provided' do
        subject(:full_chemicals) { described_class.with_filter(cus: '1234567890') }

        before do
          create(:full_chemical, cus: '1234567890') # varying cus
          create(:full_chemical, cus: '1234567891') # varying cus
        end

        let(:expected_chemical) { described_class.where(cus: '1234567890').take }

        it { is_expected.to eq([expected_chemical]) }
      end

      context 'when a cas_rn filter is provided' do
        subject(:full_chemicals) { described_class.with_filter(cas_rn: '1234567890') }

        before do
          create(:full_chemical, cas_rn: '1234567890') # varying cas_rns
          create(:full_chemical, cas_rn: '1234567891') # varying cas_rns
        end

        let(:expected_chemical) { described_class.where(cas_rn: '1234567890').take }

        it { is_expected.to eq([expected_chemical]) }
      end

      # rubocop:disable RSpec::EmptyExampleGroup
      context 'when an expired goods nomenclature is filtered' do
        subject(:full_chemicals) do
          TimeMachine.now { described_class.with_filter(goods_nomenclature_item_id: '0409000002') }
        end

        before do
          full_chemical = create(:full_chemical, goods_nomenclature_item_id: '0409000002')
          full_chemical.goods_nomenclature.validity_end_date = Time.zone.yesterday
          full_chemical.goods_nomenclature.save
          full_chemical.reload
        end

        it_with_refresh_materialized_view 'not return full_chemicals' do
          expect(full_chemicals).to be_empty
        end
      end
      # rubocop:enable RSpec::EmptyExampleGroup

      context 'when no filters are provided' do
        let(:filters) { {} }

        it { is_expected.to be_empty }
      end
    end

    describe '.by_code' do
      subject(:full_chemicals) { described_class.by_code(code) }

      let!(:full_chemical) { create(:full_chemical, goods_nomenclature_item_id: '0409000000') }

      context 'when an existing code is provided' do
        let(:code) { '0409000000' }

        it { is_expected.to include(full_chemical) }
      end

      context 'when a non-existing code is provided' do
        let(:code) { '0409000001' }

        it { is_expected.to be_empty }
      end

      context 'when a nil code is provided' do
        let(:code) { nil }

        it { expect(full_chemicals).to be_a(Sequel::Dataset) }
      end
    end

    describe '.by_suffix' do
      subject(:full_chemicals) { described_class.by_suffix(suffix) }

      let!(:full_chemical) { create(:full_chemical, producline_suffix: '80') }

      context 'when an existing suffix is provided' do
        let(:suffix) { '80' }

        it { is_expected.to include(full_chemical) }
      end

      context 'when a non-existing suffix is provided' do
        let(:suffix) { '81' }

        it { is_expected.to be_empty }
      end

      context 'when a nil suffix is provided' do
        let(:suffix) { nil }

        it { expect(full_chemicals).to be_a(Sequel::Dataset) }
      end
    end

    describe '.by_cus' do
      subject(:full_chemicals) { described_class.by_cus(cus) }

      let!(:full_chemical) { create(:full_chemical, cus: '0154438-3') }

      context 'when an existing cus is provided' do
        let(:cus) { '0154438-3' }

        it { is_expected.to include(full_chemical) }
      end

      context 'when a non-existing cus is provided' do
        let(:cus) { '0154438-4' }

        it { is_expected.to be_empty }
      end

      context 'when a nil cus is provided' do
        let(:cus) { nil }

        it { expect(full_chemicals).to be_a(Sequel::Dataset) }
      end
    end

    describe '.by_cas_rn' do
      subject(:full_chemicals) { described_class.by_cas_rn(cas_rn) }

      let!(:full_chemical) { create(:full_chemical, cas_rn: '8028-66-8') }

      context 'when an existing cas_rn is provided' do
        let(:cas_rn) { '8028-66-8' }

        it { is_expected.to include(full_chemical) }
      end

      context 'when a non-existing cas_rn is provided' do
        let(:cas_rn) { '8028-66-9' }

        it { is_expected.to be_empty }
      end

      context 'when a nil cas_rn is provided' do
        let(:cas_rn) { nil }

        it { expect(full_chemicals).to be_a(Sequel::Dataset) }
      end
    end
  end
end
