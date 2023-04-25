  class ChemicalSubstanceInBatchesFetcherService
    CHEMICAL_SUBSTANCE_WSDL = 'https://ec.europa.eu/taxation_customs/dds2/ecics/cs/services/chemical-substance?wsdl'.freeze
    CHEMICAL_SUBSTANCE_OPERATION_XML = <<~XML.freeze
<?xml version="1.0" encoding="utf-8"?>
<soap-env:Envelope xmlns:soap-env="http://schemas.xmlsoap.org/soap/envelope/">
  <soap-env:Body>
    <ns0:chemicalSubstanceForWs xmlns:ns0="http://chemicalsubstanceforWS.ws.ecics.dds.s/">
      <ns0:cnCode>29145000</ns0:cnCode>
      <ns0:languageCode>en</ns0:languageCode>
    </ns0:chemicalSubstanceForWs>
  </soap-env:Body>
</soap-env:Envelope>
    XML
    SOAP_ACTION = 'http://chemicalsubstanceforWS.ws.ecics.dds.s/chemicalSubstanceForWs'.freeze

    POSSIBLE_PRODUCLINE_SUFFIXES = %w[
      10
      20
      30
      40
      50
      60
      70
      80
    ].freeze


    MAX_CAS_NUMBERS_PER_REQUEST = 10 # This is a hard limit set by the EU SOAP API
    CHEMICAL_SUBSTANCES_BATCH_SIZE = 5000 # This is our limit for optimising inserts
    CONCURRENCY_LIMIT = 5

    def initialize
      @all_chemicals = []
    end

    def call
      headers = {
        'Content-Type' => 'text/xml;charset=UTF-8',
        'SOAPAction' => SOAP_ACTION,
      }
      method = :post

      cas_numbers.first(50).each_slice(MAX_CAS_NUMBERS_PER_REQUEST) do |cas_rns|
        body = generate_xml(cas_rns)
        request = Typhoeus::Request.new(CHEMICAL_SUBSTANCE_WSDL, method:, body:, headers:)

        request.on_complete do |response|
          if response.success?
            process_chemicals(response)
          else
            puts "Request failed: #{response.code} #{response.return_message}"
          end
        end

        client.queue(request)
      end

      client.run

      CSV.open('chemicals.csv', 'w') do |csv|
        csv << %w[
          cus_number
          cas_rn
          cn_code
          ec_number
          un_number
          name
        ]

        @all_chemicals.each do |chemical|
          csv << [
            chemical['cus'],
            chemical['cas_rn'],
            chemical['cn_code'],
            chemical['ec_number'],
            chemical['un_number'],
            chemical['name'],
          ]
        end
      end

      @all_chemicals

    end

    private

    def process_chemicals(response)
      chemical_substances = Hash
        .from_xml(response.body)
        .dig(
          'S:Envelope',
          'S:Body',
          'ns0:chemicalSubstanceForWsResponse',
          'return',
          'result',
        )
      puts "Processing #{chemical_substances.size} chemicals"
      chemical_substances.each do |chemical_substance|
        chemical_substance = chemical_substance.slice(
          'cus_number',
          'cas_rn',
          'cn_code',
          'ec_number',
          'un_number',
          'names',
        )

        goods_nomenclature_item_id = chemical_substance.delete('cn_code').to_s.ljust(10, '0')
        producline_suffix = first_matching_pls_for(goods_nomenclature_item_id)

        full_cn_code = "#{goods_nomenclature_item_id}-#{producline_suffix}"

        names = chemical_substance.delete('names')['name']
        name = latest_chemical_name_in(names)

        chemical_substance['cus'] = chemical_substance.delete('cus_number')
        chemical_substance['goods_nomenclature_item_id'] = goods_nomenclature_item_id
        chemical_substance['producline_suffix'] = producline_suffix
        chemical_substance['cn_code'] = full_cn_code
        chemical_substance['name'] = name['description']
        chemical_substance['nomen'] = name['nomenclature']

        @all_chemicals << chemical_substance
      end
    end

    def generate_xml(cas_numbers)
      template = ERB.new(CHEMICAL_SUBSTANCE_OPERATION_XML)
      template.result_with_hash(cas_numbers:)
    end

    def first_matching_pls_for(goods_nomenclature_item_id)
      POSSIBLE_PRODUCLINE_SUFFIXES.find do |suffix|
        cn_codes.include?("#{goods_nomenclature_item_id}-#{suffix}")
      end
    end

    def latest_chemical_name_in(names)
      names = Array.wrap(names)

      names
        .select { |name| name['level'] == 'Name' }
        .min_by { |name| name['order'].to_i }
    end

    def client
      @client ||= Typhoeus::Hydra.new(max_concurrency: CONCURRENCY_LIMIT)
    end

    def cas_numbers
      @cas_numbers ||= TimeMachine.now do
        GoodsNomenclatureDescription.all_cas_numbers
      end
    end

    def cn_codes
      @cn_codes ||= GoodsNomenclature.cn_codes
    end

    def cn_codes_8_digits
      @cn_codes_8_digits ||= GoodsNomenclatureDescription
        .all_item_ids
        .map { |item_id| item_id.to_s.first(8) }
    end
  end
