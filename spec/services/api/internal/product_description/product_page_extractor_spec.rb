RSpec.describe Api::Internal::ProductDescription::ProductPageExtractor do
  describe '.call' do
    it 'extracts product signals from html metadata and JSON-LD' do
      html = <<~HTML
        <html>
          <head>
            <title>Cotton T-shirt | Example</title>
            <meta name="description" content="A soft short-sleeved T-shirt made from cotton.">
            <meta property="og:title" content="Men's cotton T-shirt">
            <meta property="og:description" content="Crew neck cotton top for casual wear.">
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "Product",
                "name": "Cotton T-shirt",
                "brand": { "name": "Example" },
                "material": "100% cotton",
                "description": "A lightweight knitted T-shirt."
              }
            </script>
          </head>
          <body>
            <h1>Men's cotton T-shirt</h1>
            <p>This product has short sleeves, a crew neck and a regular fit.</p>
            <script>window.secret = "ignore me"</script>
          </body>
        </html>
      HTML

      result = described_class.call(html)

      expect(result).to have_attributes(
        title: 'Cotton T-shirt | Example',
        meta_description: 'A soft short-sleeved T-shirt made from cotton.',
        open_graph_title: "Men's cotton T-shirt",
        open_graph_description: 'Crew neck cotton top for casual wear.',
        h1: "Men's cotton T-shirt",
      )
      expect(result.product_data).to include(
        'name' => 'Cotton T-shirt',
        'brand' => 'Example',
        'material' => '100% cotton',
        'description' => 'A lightweight knitted T-shirt.',
      )
      expect(result.body_text).to include('short sleeves')
      expect(result.body_text).not_to include('ignore me')
      expect(result).to be_sufficient
    end

    it 'extracts Product entries from JSON-LD graphs' do
      html = <<~HTML
        <script type="application/ld+json">
          {
            "@graph": [
              { "@type": "BreadcrumbList", "name": "Breadcrumbs" },
              { "@type": ["Thing", "Product"], "name": "Leather belt", "brand": "Example" }
            ]
          }
        </script>
      HTML

      result = described_class.call(html)

      expect(result.product_data).to include('name' => 'Leather belt', 'brand' => 'Example')
      expect(result).to be_sufficient
    end

    it 'marks pages with no product signals as insufficient' do
      result = described_class.call('<html><body><nav>Home</nav></body></html>')

      expect(result).not_to be_sufficient
    end
  end
end
