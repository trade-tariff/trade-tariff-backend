require 'rails_helper'

describe Footnote do
  describe 'associations' do
    describe 'additional code description' do
      let!(:footnote) { create :footnote }
      let!(:footnote_description_2) do
        create :footnote_description, :with_period,
          footnote_id: footnote.footnote_id,
          footnote_type_id: footnote.footnote_type_id,
          valid_at: 2.years.ago,
          valid_to: nil
      end
      let!(:footnote_description_3) do
        create :footnote_description, :with_period,
          footnote_id: footnote.footnote_id,
          footnote_type_id: footnote.footnote_type_id,
          valid_at: 5.years.ago,
          valid_to: 3.years.ago
      end

      it 'loads correct description respecting given actual time' do
        TimeMachine.now do
          expect(
            footnote.footnote_description.pk,
          ).to eq footnote_description_2.pk
        end
      end

      it 'loads correct description respecting given time' do
        TimeMachine.at(1.year.ago) do
          expect(
            footnote.footnote_description.pk,
          ).to eq footnote_description_2.pk
        end
      end
    end
  end

  describe 'validations' do
    # FO1 The referenced footnote type must exist.
    it { is_expected.to validate_presence.of(:footnote_type) }
    # FO2 The combination footnote type and code must be unique.
    it { is_expected.to validate_uniqueness.of(%i[footnote_type_id footnote_id]) }
    # FO3 The start date must be less than or equal to the end date.
    it { is_expected.to validate_validity_dates }

    describe 'FO4' do
      describe 'At least one description record is mandatory' do
        let(:footnote) { create :footnote }

        before { footnote.footnote_description_periods.each(&:destroy) }

        it 'performs validation' do
          expect(footnote.reload).not_to be_conformant
        end
      end

      describe 'The start date of the first description period must be equal to the start date of the footnote.' do
        let(:footnote) { create :footnote }
        let(:desc_period) { footnote.footnote_description_periods.first }

        it 'performs validation' do
          desc_period.update(validity_start_date: footnote.validity_start_date + 1.day)
          expect(footnote.reload).not_to be_conformant
        end
      end

      describe 'No two associated description periods may have the same start date.' do
        let(:footnote)      { create :footnote }
        let(:desc_period1)  { footnote.footnote_description_periods.first }
        let!(:desc_period2) do
          create :footnote_description_period, footnote_type_id: footnote.footnote_type_id,
                                               footnote_id: footnote.footnote_id,
                                               validity_start_date: footnote.validity_start_date
        end

        it 'performs validation' do
          expect(footnote.reload).not_to be_conformant
        end
      end

      describe 'The start date must be less than or equal to the end date of the footnote.' do
        let(:footnote)    { create :footnote, validity_end_date: Date.current }
        let(:desc_period) { footnote.footnote_description_periods.first }

        before { desc_period.update(validity_start_date: footnote.validity_end_date + 1.day) }

        it 'performs validation' do
          expect(footnote.reload).not_to be_conformant
        end
      end
    end

    describe 'FO5' do
      let!(:measure) { create :measure }
      let!(:footnote) { create :footnote, validity_start_date: Date.new(2009, 1, 1) }
      let!(:association) do
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                              footnote_id: footnote.footnote_id,
                                              footnote_type_id: footnote.footnote_type_id
      end

      it 'performs validation' do
        expect(footnote).to be_conformant

        footnote.validity_start_date = measure.validity_start_date + 1
        expect(footnote).not_to be_conformant
      end
    end

    describe 'FO6' do
      let!(:goods_nomenclature) { create :goods_nomenclature }
      let!(:footnote) { create :footnote, validity_start_date: Date.new(2009, 1, 1) }
      let!(:association) do
        create :footnote_association_goods_nomenclature, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                                                         footnote_id: footnote.footnote_id,
                                                         footnote_type: footnote.footnote_type_id
      end

      it 'performs validation' do
        expect(footnote).to be_conformant

        footnote.validity_start_date = goods_nomenclature.validity_start_date + 1
        expect(footnote).not_to be_conformant
      end
    end

    describe 'FO7' do
      let!(:export_refund_nomenclature) { create :export_refund_nomenclature }
      let!(:footnote) { create :footnote, validity_start_date: Date.new(2009, 1, 1) }
      let!(:association) do
        create :footnote_association_ern, export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
                                          footnote_id: footnote.footnote_id,
                                          footnote_type: footnote.footnote_type_id
      end

      it 'performs validation' do
        expect(footnote).to be_conformant

        footnote.validity_start_date = export_refund_nomenclature.validity_start_date + 1
        expect(footnote).not_to be_conformant
      end
    end

    describe 'FO9' do
      let!(:additional_code) { create :additional_code }
      let!(:footnote) { create :footnote, validity_start_date: Date.new(2009, 1, 1) }
      let!(:association) do
        create :footnote_association_additional_code, additional_code_sid: additional_code.additional_code_sid,
                                                      footnote_id: footnote.footnote_id,
                                                      footnote_type_id: footnote.footnote_type_id
      end

      it 'performs validation' do
        expect(footnote).to be_conformant

        footnote.validity_start_date = additional_code.validity_start_date + 1
        expect(footnote).not_to be_conformant
      end
    end

    describe 'FO10' do
      it { is_expected.to validate_validity_date_span.of(:meursing_headings) }
    end

    describe 'FO17' do
      it { is_expected.to validate_validity_date_span.of(:footnote_type) }
    end

    describe 'FO11' do
      let!(:footnote) { create :footnote }
      let!(:measure)  { create :measure }
      let!(:footnote_association_measure) do
        create :footnote_association_measure, footnote_id: footnote.footnote_id,
                                              footnote_type_id: footnote.footnote_type_id,
                                              measure_sid: measure.measure_sid
      end

      before do
        footnote.destroy
        footnote.conformant?
      end

      specify 'When a footnote is used in a measure then the footnote may not be deleted.' do
        expect(footnote.conformance_errors.keys).to include :FO11
      end
    end

    describe 'FO12' do
      let!(:footnote) { create :footnote }
      let!(:gono) { create :goods_nomenclature }
      let!(:footnote_association_goods_nomenclature) do
        create :footnote_association_goods_nomenclature, footnote_id: footnote.footnote_id,
                                                         footnote_type: footnote.footnote_type_id,
                                                         goods_nomenclature_sid: gono.goods_nomenclature_sid
      end

      before do
        footnote.destroy
        footnote.conformant?
      end

      specify 'When a footnote is used in a goods nomenclature then the footnote may not be deleted.' do
        expect(footnote.conformance_errors.keys).to include :FO12
      end
    end

    describe 'FO13' do
      let!(:footnote) { create :footnote }
      let!(:ern) { create :export_refund_nomenclature }
      let!(:footnote_association_ern) do
        create :footnote_association_ern, footnote_id: footnote.footnote_id,
                                          footnote_type: footnote.footnote_type_id,
                                          export_refund_nomenclature_sid: ern.export_refund_nomenclature_sid
      end

      before do
        footnote.destroy
        footnote.conformant?
      end

      specify 'When a footnote is used in an Export Refund code then the footnote may not be deleted.' do
        expect(footnote.conformance_errors.keys).to include :FO13
      end
    end

    describe 'FO15' do
      let!(:footnote) { create :footnote }
      let!(:adco) { create :additional_code }
      let!(:footnote_association_additional_code) do
        create :footnote_association_additional_code, footnote_id: footnote.footnote_id,
                                                      footnote_type_id: footnote.footnote_type_id,
                                                      additional_code_sid: adco.additional_code_sid
      end

      before do
        footnote.destroy
        footnote.conformant?
      end

      specify 'When a footnote is used in an additional code then the footnote may not be deleted.' do
        expect(footnote.conformance_errors.keys).to include :FO15
      end
    end

    describe 'FO16' do
      let!(:footnote) { create :footnote }
      let!(:meursing_heading)  { create :meursing_heading }
      let!(:footnote_association_meursing_heading) do
        create :footnote_association_meursing_heading, footnote_id: footnote.footnote_id,
                                                       footnote_type: footnote.footnote_type_id,
                                                       meursing_table_plan_id: meursing_heading.meursing_table_plan_id,
                                                       meursing_heading_number: meursing_heading.meursing_heading_number
      end

      before do
        footnote.destroy
        footnote.conformant?
      end

      specify 'When a footnote is used in a Meursing Table heading then the footnote may not be deleted.' do
        expect(footnote.conformance_errors.keys).to include :FO16
      end
    end
  end

  describe '#code' do
    let(:footnote) { build :footnote }

    it 'returns conjuction of footnote type id and footnote id' do
      expect(footnote.code).to eq [footnote.footnote_type_id, footnote.footnote_id].join
    end
  end
end
