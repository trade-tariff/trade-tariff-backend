RSpec.describe ApplicationHelper do
  describe '#regulation_url' do
    context 'for base_regulation' do
      context 'for Official Journal - C (Information and Notices) seria' do
        let(:base_regulation) do
          create(:base_regulation, base_regulation_id: 'I1703530',
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 10, 20),
                                   officialjournal_number: 'C 353',
                                   officialjournal_page: 19)
        end

        let(:measure) do
          create(:measure, goods_nomenclature_item_id: '8711601000',
                           measure_generating_regulation_id: 'I1703530',
                           base_regulation:)
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.generating_regulation)).to eql('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32017I0353')
        end
      end

      context 'for Official Journal - L (Legislation) seria' do
        let(:base_regulation) do
          create(:base_regulation, base_regulation_id: 'R1708920',
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 0o5, 25),
                                   officialjournal_number: 'L 138',
                                   officialjournal_page: 57)
        end

        let(:measure) do
          create(:measure, goods_nomenclature_item_id: '0808108000',
                           measure_generating_regulation_id: 'R1708920',
                           base_regulation:)
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.generating_regulation)).to eql('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32017R0892')
        end
      end
    end

    describe '#regulation_code' do
      let(:measure) do
        create :measure, generating_regulation: create(:base_regulation, base_regulation_id: '1234567')
      end

      it 'returns generating regulation code in TARIC format' do
        expect(regulation_code(measure.generating_regulation)).to eq '14567/23'
      end
    end
  end
end
