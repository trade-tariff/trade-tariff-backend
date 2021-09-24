RSpec.describe ExportRefundNomenclature do
  describe 'associations' do
    describe 'export refund nomenclature indent' do
      let!(:export_refund_nomenclature)                { create :export_refund_nomenclature }
      let!(:export_refund_nomenclature_indent1)        do
        create :export_refund_nomenclature_indent,
               export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
               validity_start_date: 2.years.ago,
               validity_end_date: nil
      end
      let!(:export_refund_nomenclature_indent2) do
        create :export_refund_nomenclature_indent,
               export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
               validity_start_date: 5.years.ago,
               validity_end_date: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              export_refund_nomenclature.export_refund_nomenclature_indent.pk,
            ).to eq export_refund_nomenclature_indent1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              export_refund_nomenclature.reload.export_refund_nomenclature_indent.pk,
            ).to eq export_refund_nomenclature_indent2.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid)
                             .eager(:export_refund_nomenclature_indents)
                             .all
                             .first
                             .export_refund_nomenclature_indent.pk,
            ).to eq export_refund_nomenclature_indent1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid)
                          .eager(:export_refund_nomenclature_indents)
                          .all
                          .first
                          .export_refund_nomenclature_indent.pk,
            ).to eq export_refund_nomenclature_indent2.pk
          end
        end
      end
    end

    describe 'export refund nomenclature description' do
      let!(:export_refund_nomenclature)                { create :export_refund_nomenclature }
      let!(:export_refund_nomenclature_description1)   do
        create :export_refund_nomenclature_description,
               export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
               valid_at: 2.years.ago,
               valid_to: nil
      end
      let!(:export_refund_nomenclature_description2) do
        create :export_refund_nomenclature_description,
               export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
               valid_at: 5.years.ago,
               valid_to: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              export_refund_nomenclature.export_refund_nomenclature_description.pk,
            ).to eq export_refund_nomenclature_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              export_refund_nomenclature.reload.export_refund_nomenclature_description.pk,
            ).to eq export_refund_nomenclature_description2.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid)
                          .eager(:export_refund_nomenclature_descriptions)
                          .all
                          .first
                          .export_refund_nomenclature_description.pk,
            ).to eq export_refund_nomenclature_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid)
                          .eager(:export_refund_nomenclature_descriptions)
                          .all
                          .first
                          .export_refund_nomenclature_description.pk,
            ).to eq export_refund_nomenclature_description2.pk
          end
        end
      end
    end
  end

  describe '#additional_code' do
    let(:export_refund_nomenclature) { build :export_refund_nomenclature }

    it 'is a concatenation of additional code type and export refund code' do
      expect(
        export_refund_nomenclature.additional_code,
      ).to eq "#{export_refund_nomenclature.additional_code_type}#{export_refund_nomenclature.export_refund_code}"
    end
  end
end
