require 'rails_helper'

describe Certificate do
  describe 'associations' do
    describe 'certificate description' do
      let!(:certificate)                { create :certificate }
      let!(:certificate_description1)   do
        create :certificate_description, :with_period,
               certificate_type_code: certificate.certificate_type_code,
               certificate_code: certificate.certificate_code,
               valid_at: 2.years.ago,
               valid_to: nil
      end
      let!(:certificate_description2) do
        create :certificate_description, :with_period,
               certificate_type_code: certificate.certificate_type_code,
               certificate_code: certificate.certificate_code,
               valid_at: 5.years.ago,
               valid_to: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              certificate.certificate_description.pk,
            ).to eq certificate_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              certificate.certificate_description.pk,
            ).to eq certificate_description1.pk
          end

          TimeMachine.at(4.years.ago) do
            expect(
              certificate.reload.certificate_description.pk,
            ).to eq certificate_description2.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(certificate_type_code: certificate.certificate_type_code,
                                    certificate_code: certificate.certificate_code)
                        .eager(:certificate_descriptions)
                        .all
                        .first
                        .certificate_description.pk,
            ).to eq certificate_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              described_class.where(certificate_type_code: certificate.certificate_type_code,
                                    certificate_code: certificate.certificate_code)
                        .eager(:certificate_descriptions)
                        .all
                        .first
                        .certificate_description.pk,
            ).to eq certificate_description1.pk
          end

          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(certificate_type_code: certificate.certificate_type_code,
                                    certificate_code: certificate.certificate_code)
                       .eager(:certificate_descriptions)
                       .all
                       .first
                       .certificate_description.pk,
            ).to eq certificate_description2.pk
          end
        end
      end
    end

    describe 'certificate type' do
      it_is_associated 'one to one to', :certificate_type, :certificate_types do
        let(:certificate_type_code) { Forgery(:basic).text(exactly: 1) }
      end
    end
  end

  describe 'validations' do
  end
end
