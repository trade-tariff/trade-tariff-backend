RSpec.describe FullChemicalPopulatorService do
  describe '#call' do
    subject(:call) { described_class.new.call }

    before do
      stub_const('FullChemicalPopulatorService::CSV_FILE', Rails.root.join('spec/fixtures/full_chemicals.csv'))
    end

    context 'when there are preexisting full chemicals' do
      before do
        create(:goods_nomenclature, goods_nomenclature_item_id: '0409000000', producline_suffix: '80')
        create(:goods_nomenclature, goods_nomenclature_item_id: '0511998590', producline_suffix: '80')
      end

      let!(:full_chemical) do
        create(
          :full_chemical,
          cus: '0154438-3',
          cn_code: '0409000000-80',
          cas_rn: '8028-66-8',
          ec_number: '293-255-4',
          goods_nomenclature_item_id: '0409000000',
          producline_suffix: '80',
          un_number: nil,
          nomen: 'COMMON', # Changed
          name: 'powder', # Changed
        )
      end

      let(:change_value) { ->(value) { change { full_chemical.reload.public_send(value) } } }

      it { expect { call }.to change_value.call(:nomen) }
      it { expect { call }.to change_value.call(:name) }
      it { expect { call }.to change_value.call(:updated_at) }
      it { expect { call }.not_to change_value.call(:created_at) }
    end

    context 'when there are matching goods nomenclatures' do
      before do
        create(:goods_nomenclature, goods_nomenclature_item_id: '0409000000', producline_suffix: '80')
        create(:goods_nomenclature, goods_nomenclature_item_id: '0511998590', producline_suffix: '80')
      end

      it { expect { call }.to change(FullChemical, :count).by(2) }

      it 'creates a full chemical with the correct values' do
        call

        expect(FullChemical.find(cus: '0154438-3')).to have_attributes(
          cn_code: '0409000000-80',
          cas_rn: '8028-66-8',
          ec_number: '293-255-4',
          un_number: nil,
          nomen: 'INCI',
          name: 'mel powder',
          goods_nomenclature_sid: be_a(Integer),
          goods_nomenclature_item_id: '0409000000',
          producline_suffix: '80',
          updated_at: be_a(Time),
          created_at: be_a(Time),
        )
      end
    end

    context 'when there are no current matching goods nomenclatures' do
      before do
        create(:goods_nomenclature, :non_current, goods_nomenclature_item_id: '0409000000', producline_suffix: '80')
        create(:goods_nomenclature, :non_current, goods_nomenclature_item_id: '0511998590', producline_suffix: '80')
      end

      it { expect { call }.to raise_error(Sequel::NotNullConstraintViolation) }
    end
  end
end
