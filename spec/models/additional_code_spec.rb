RSpec.describe AdditionalCode do
  subject(:additional_code) do
    build(
      :additional_code,
      additional_code_type_id:,
    )
  end

  let(:additional_code_type_id) { '2' }

  describe 'associations' do
    describe 'additional code description' do
      before do
        create :additional_code_description, :with_period,
               additional_code_sid: additional_code.additional_code_sid,
               valid_at: 6.years.ago.beginning_of_day,
               valid_to: 1.year.ago.beginning_of_day
      end

      let!(:additional_code)                { create :additional_code }
      let!(:additional_code_description1)   do
        create :additional_code_description, :with_period,
               additional_code_sid: additional_code.additional_code_sid,
               valid_at: 2.years.ago.beginning_of_day,
               valid_to: nil
      end
      let!(:additional_code_description2) do
        create :additional_code_description, :with_period,
               additional_code_sid: additional_code.additional_code_sid,
               valid_at: 5.years.ago.beginning_of_day,
               valid_to: 3.years.ago.beginning_of_day
      end

      context 'when direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              additional_code.additional_code_description.pk,
            ).to eq additional_code_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              additional_code.reload.additional_code_description.pk,
            ).to eq additional_code_description2.pk
          end
        end
      end

      context 'when eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(additional_code_sid: additional_code.additional_code_sid)
                          .eager(:additional_code_descriptions)
                          .all
                          .first
                          .additional_code_description.pk,
            ).to eq additional_code_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              described_class.where(additional_code_sid: additional_code.additional_code_sid)
                          .eager(:additional_code_descriptions)
                          .all
                          .first
                          .additional_code_description.pk,
            ).to eq additional_code_description1.pk
          end
        end
      end
    end
  end

  describe '#code' do
    let(:additional_code) { build :additional_code }

    it 'returns conjucation of additional code type id and additional code' do
      expect(
        additional_code.code,
      ).to eq [additional_code.additional_code_type_id, additional_code.additional_code].join
    end
  end

  describe '#type' do
    context 'when the type id is of a preference type' do
      let(:additional_code_type_id) { '2' }

      it { expect(additional_code.type).to eq('preference') }
    end

    context 'when the type id is of a remedy type' do
      let(:additional_code_type_id) { '8' }

      it { expect(additional_code.type).to eq('remedy') }
    end

    context 'when the type id is not currently handled' do
      let(:additional_code_type_id) { 'Z' }

      it { expect(additional_code.type).to eq('unknown') }
    end

    context 'when the type id is of a excise type' do
      let(:additional_code_type_id) { 'X' }

      it { expect(additional_code.type).to eq('excise') }
    end
  end

  describe '#applicable?' do
    context 'when the type is unknown' do
      let(:additional_code_type_id) { 'Z' }

      it { is_expected.not_to be_applicable }
    end

    context 'when the type is not unknown' do
      let(:additional_code_type_id) { '2' }

      it { is_expected.to be_applicable }
    end
  end

  describe '.null_code' do
    it { expect(described_class.null_code.code).to eq('none') }
    it { expect(described_class.null_code.description).to eq('No additional code') }
  end
end
