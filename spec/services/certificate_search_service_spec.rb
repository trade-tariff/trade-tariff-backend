describe CertificateSearchService do
  describe 'certificate search' do
    around do |example|
      TimeMachine.now { example.run }
    end

    let!(:certificate_1) { create :certificate }
    let!(:certificate_description_1) do
      create :certificate_description,
             :with_period,
             certificate_type_code: certificate_1.certificate_type_code,
             certificate_code: certificate_1.certificate_code
    end
    let!(:measure_1) { create :measure }
    let!(:goods_nomenclature_1) { measure_1.goods_nomenclature }
    let!(:measure_condition_1) do
      create :measure_condition,
             certificate_type_code: certificate_1.certificate_type_code,
             certificate_code: certificate_1.certificate_code,
             measure_sid: measure_1.measure_sid
    end

    let!(:certificate_2) { create :certificate }
    let!(:certificate_description_2) do
      create :certificate_description,
             :with_period,
             certificate_type_code: certificate_2.certificate_type_code,
             certificate_code: certificate_2.certificate_code
    end
    let!(:measure_2) { create :measure }
    let!(:goods_nomenclature_2) { measure_2.goods_nomenclature }
    let!(:measure_condition_2) do
      create :measure_condition,
             certificate_type_code: certificate_2.certificate_type_code,
             certificate_code: certificate_2.certificate_code,
             measure_sid: measure_2.measure_sid
    end
    let(:current_page) { 1 }
    let(:per_page) { 20 }

    before do
      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex
        sleep(1)
      end
    end

    context 'by certificate code' do
      it 'finds certificate by code' do
        result = described_class.new({
          'code' => certificate_1.certificate_code,
        }, current_page, per_page).perform
        expect(result.map(&:id)).to include(certificate_1.id)
      end

      it 'does not find additional code by wrong code' do
        result = described_class.new({
          'code' => certificate_1.certificate_code,
        }, current_page, per_page).perform
        expect(result.map(&:id)).not_to include(certificate_2.id)
      end

      context 'when user enter 4-digits code' do
        it 'finds certificate by code' do
          result = described_class.new({
            'code' => "#{rand(9)}#{certificate_1.certificate_code}",
          }, current_page, per_page).perform
          expect(result.map(&:id)).to include(certificate_1.id)
        end

        it 'ignores first digit' do
          service = described_class.new({
            'code' => "#{rand(9)}#{certificate_1.certificate_code}",
          }, current_page, per_page)
          service.perform
          expect(service.code).to eq(certificate_1.certificate_code)
        end
      end
    end

    context 'by certificate type' do
      it 'finds certificate by type' do
        result = described_class.new({
          'type' => certificate_1.certificate_type_code,
        }, current_page, per_page).perform
        expect(result.map(&:id)).to include(certificate_1.id)
      end

      it 'does not find additional code by wrong type' do
        result = described_class.new({
          'type' => certificate_1.certificate_type_code,
        }, current_page, per_page).perform
        expect(result.map(&:id)).not_to include(certificate_2.id)
      end
    end

    context 'by description' do
      it 'finds certificate by description' do
        result = described_class.new({
          'description' => certificate_1.description,
        }, current_page, per_page).perform
        expect(result.map(&:id)).to include(certificate_1.id)
      end

      it 'does not find certificate by wrong description' do
        result = described_class.new({
          'description' => certificate_1.description,
        }, current_page, per_page).perform
        expect(result.map(&:id)).not_to include(certificate_2.id)
      end
    end

    context 'by description first word' do
      it 'finds certificate by description first word' do
        result = described_class.new({
          'description' => certificate_1.description.split(' ').first,
        }, current_page, per_page).perform
        expect(result.map(&:id)).to include(certificate_1.id)
      end

      it 'does not find certificate by wrong description first word' do
        result = described_class.new({
          'description' => certificate_1.description.split(' ').first,
        }, current_page, per_page).perform
        expect(result.map(&:id)).not_to include(certificate_2.id)
      end
    end
  end
end
