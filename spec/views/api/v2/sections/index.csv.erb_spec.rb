RSpec.describe 'api/v2/sections/index.csv' do
  before do
    assign(:sections, sections)
  end

  let(:sections) do
    [
      build(
        :section,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      ),
    ]
  end

  let(:expected_csv) { "id,numeral,title,position,chapter_from,chapter_to\n18,XVIII,\"Optical, photographic, cinematographic, measuring\",18,,\n" }

  it { expect(render).to eq(expected_csv) }
end
