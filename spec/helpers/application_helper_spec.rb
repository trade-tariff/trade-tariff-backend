RSpec.describe ApplicationHelper do
  describe '#regulation_url' do
    context 'for base_regulation' do
      context 'for Official Journal - C (Information and Notices) seria' do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: 'I1703530',
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 10, 20),
                                   officialjournal_number: 'C 353',
                                   officialjournal_page: 19)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: '8711601000',
                           measure_generating_regulation_id: 'I1703530',
                           base_regulation: base_regulation)
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.generating_regulation)).to be_eql('http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D353,YEAR_OJ%3D2017,PAGE_FIRST%3D0019&DB_COLL_OJ=oj-c&type=advanced&lang=en')
        end
      end

      context 'for Official Journal - L (Legislation) seria' do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: 'R1708920',
                                   base_regulation_role: 1,
                                   published_date: Date.new(2017, 0o5, 25),
                                   officialjournal_number: 'L 138',
                                   officialjournal_page: 57)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: '0808108000',
                           measure_generating_regulation_id: 'R1708920',
                           base_regulation: base_regulation)
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.generating_regulation)).to be_eql('http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D138,YEAR_OJ%3D2017,PAGE_FIRST%3D0057&DB_COLL_OJ=oj-l&type=advanced&lang=en')
        end
      end
    end

    context 'for suspending_regulation' do
      context 'for FullTemporaryStopRegulation' do
        let!(:fts_regulation) do
          create(:fts_regulation, full_temporary_stop_regulation_id: 'R9528150',
                                  full_temporary_stop_regulation_role: 8,
                                  published_date: Date.new(1995, 12, 9),
                                  officialjournal_number: 'L 297',
                                  officialjournal_page: 1)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: '0100000000',
                           measure_generating_regulation_id: 'R9309900')
        end

        let!(:fts_regulation_action) do
          create(:fts_regulation_action, fts_regulation_role: 8,
                                         fts_regulation_id: 'R9528150',
                                         stopped_regulation_role: 1,
                                         stopped_regulation_id: 'R9309900')
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.suspending_regulation)).to be_eql(
            'http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D297,YEAR_OJ%3D1995,PAGE_FIRST%3D0001&DB_COLL_OJ=oj-l&type=advanced&lang=en',
          )
        end
      end

      context 'for MeasurePartialTemporaryStop' do
        let!(:base_regulation) do
          create(:base_regulation, base_regulation_id: 'R0912150',
                                   base_regulation_role: 1,
                                   published_date: Date.new(2009, 12, 15),
                                   officialjournal_number: 'L 328',
                                   officialjournal_page: 1)
        end

        let!(:measure) do
          create(:measure, goods_nomenclature_item_id: '2823000000',
                           measure_generating_regulation_id: 'R0912150',
                           base_regulation: base_regulation)
        end

        let!(:measure_partial_temporary_stop) do
          create(:measure_partial_temporary_stop, measure_sid: measure.measure_sid,
                                                  partial_temporary_stop_regulation_id: 'R0912150',
                                                  validity_start_date: DateTime.parse('2010-01-04T00:00:00.000Z'),
                                                  officialjournal_number: 'L 328',
                                                  officialjournal_page: 6)
        end

        before do
          measure.reload
        end

        it 'generates council regulation url' do
          expect(regulation_url(measure.suspending_regulation)).to be_eql(
            'http://eur-lex.europa.eu/search.html?whOJ=NO_OJ%3D328,PAGE_FIRST%3D0006&DB_COLL_OJ=oj-l&type=advanced&lang=en',
          )
        end
      end
    end
  end

  describe '#regulation_code' do
    let(:measure) do
      build :measure,
            measure_generating_regulation_id: '1234567'
    end

    it 'returns generating regulation code in TARIC format' do
      expect(regulation_code(measure.generating_regulation)).to eq '14567/23'
    end
  end
end
