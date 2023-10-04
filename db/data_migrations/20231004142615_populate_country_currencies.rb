CSV_FILE = <<~FILE.freeze
  country_description,currency_description,currency_code,validity_start_date,validity_end_date,country_code
  Abu Dhabi,Dirham,AED,2020-01-01,,DH
  Afghanistan,Afghani,AFN,2020-01-01,,AF
  Albania,Lek,ALL,2020-01-01,,AL
  Algeria,Dinar,DZD,2020-01-01,,DZ
  Angola,Kwanza,AOA,2020-01-01,,AO
  Anguilla,Eastern Caribbean dollar,XCD,2020-01-01,,AI
  Antigua and Barbuda,Eastern Caribbean dollar,XCD,2020-01-01,,AG
  Argentina,Peso,ARS,2020-01-01,,AR
  Armenia,Dram,AMD,2020-01-01,,AM
  Aruba,Florin,AWG,2020-01-01,,AW
  Australia,Dollar,AUD,2020-01-01,,AU
  Azerbaijan,Manat,AZN,2020-01-01,,AZ
  Bahamas,Dollar,BSD,2020-01-01,,BS
  Bahrain,Dinar,BHD,2020-01-01,,BH
  Bangladesh,Taka,BDT,2020-01-01,,BD
  Barbados,Dollar,BBD,2020-01-01,,BB
  Belarus,Rouble,BYN,2020-01-01,,BY
  Belize,Dollar,BZD,2020-01-01,,BZ
  Benin,West African CFA Franc,XOF,2020-01-01,,BJ
  Bermuda,Dollar (US),BMD,2020-01-01,,BM
  Bhutan,Ngultrum,BTN,2020-01-01,,BT
  Bolivia,Boliviano,BOB,2020-01-01,,BO
  Bosnia and Herzegovina,Convertible mark,BAM,2020-01-01,,BA
  Botswana,Pula,BWP,2020-01-01,,BW
  Brazil,Real,BRL,2020-01-01,,BR
  Brunei Darussalam,Dollar,BND,2020-01-01,,BN
  Bulgaria,Lev,BGN,2020-01-01,,BG
  Burkina Faso,West African CFA Franc,XOF,2020-01-01,,BF
  Burundi,Franc,BIF,2020-01-01,,BI
  Cabo Verde,Escudo,CVE,2020-01-01,,CV
  Cambodia,Riel,KHR,2020-01-01,,KH
  Cameroon,Central African CFA Franc,XAF,2020-01-01,,CM
  Canada,Dollar,CAD,2020-01-01,,CA
  Cayman Islands,Dollar,KYD,2020-01-01,,KY
  Central African Republic,Central African CFA Franc,XAF,2020-01-01,,CF
  Chad,Central African CFA Franc,XAF,2020-01-01,,TD
  Chile,Peso,CLP,2020-01-01,,CL
  China,Yuan,CNY,2020-01-01,,CN
  Colombia,Peso,COP,2020-01-01,,CO
  Comoros,Franc,KMF,2020-01-01,,KM
  Congo,Central African CFA Franc,XAF,2020-01-01,,CG
  Congo (Democratic Republic),Congolese Franc,CDF,2020-01-01,,CD
  Costa Rica,Colón,CRC,2020-01-01,,CR
  Cuba,Peso,CUP,2020-01-01,,CU
  Czechia,Koruna,CZK,2020-01-01,,CZ
  Côte d'Ivoire,West African CFA Franc,XOF,2020-01-01,,CI
  Denmark,Krone,DKK,2020-01-01,,DK
  Djibouti,Franc,DJF,2020-01-01,,DJ
  Dominica,Eastern Caribbean dollar,XCD,2020-01-01,,DM
  Dominican Republic,Peso,DOP,2020-01-01,,DO
  Dubai,Dirham,AED,2020-01-01,,DU
  Egypt,Pound,EGP,2020-01-01,,EG
  El Salvador,Colón,SVC,2020-01-01,,SV
  Equatorial Guinea,Central African CFA Franc,XAF,2020-01-01,,GQ
  Eritrea,Nakfa,ERN,2020-01-01,,ER
  Eswatini,Lilangeni,SZL,2020-01-01,,SZ
  Ethiopia,Birr,ETB,2020-01-01,,ET
  Eurozone,Euro,EUR,2020-01-01,,EU
  Fiji,Dollar,FJD,2020-01-01,,FJ
  French Polynesia,CFP Franc,XPF,2020-01-01,,PF
  Gabon,Central African CFA Franc,XAF,2020-01-01,,GA
  Gambia,Dalasi,GMD,2020-01-01,,GM
  Georgia,Lari,GEL,2020-01-01,,GE
  Ghana,Cedi,GHS,2020-01-01,,GH
  Grenada,Eastern Caribbean dollar,XCD,2020-01-01,,GD
  Guatemala,Quetzal,GTQ,2020-01-01,,GT
  Guinea,Franc,GNF,2020-01-01,,GN
  Guinea-Bissau,West African CFA Franc,XOF,2020-01-01,,GW
  Guyana,Dollar,GYD,2020-01-01,,GY
  Haiti,Gourde,HTG,2020-01-01,,HT
  Honduras,Lempira,HNL,2020-01-01,,HN
  Hong Kong,Dollar,HKD,2020-01-01,,HK
  Hungary,Forint,HUF,2020-01-01,,HU
  Iceland,Króna,ISK,2020-01-01,,IS
  India,Rupee,INR,2020-01-01,,IN
  Indonesia,Rupiah,IDR,2020-01-01,,ID
  Iran,Rial,IRR,2020-01-01,,IR
  Iraq,Dinar,IQD,2020-01-01,,IQ
  Israel,Shekel,ILS,2020-01-01,,IL
  Jamaica,Dollar,JMD,2020-01-01,,JM
  Japan,Yen,JPY,2020-01-01,,JP
  Jordan,Dinar,JOD,2020-01-01,,JO
  Kazakhstan,Tenge,KZT,2020-01-01,,KZ
  Kenya,Shilling,KES,2020-01-01,,KE
  Kuwait,Dinar,KWD,2020-01-01,,KW
  Kyrgyzstan,Som,KGS,2020-01-01,,KG
  Lao People's Democratic Republic,Kip,LAK,2020-01-01,,LA
  Lebanon,Pound,LBP,2020-01-01,,LB
  Lesotho,Loti,LSL,2020-01-01,,LS
  Liberia,Dollar (US),LRD,2020-01-01,,LR
  Libya,Dinar,LYD,2020-01-01,,LY
  Macao,Pataca,MOP,2020-01-01,,MO
  Madagascar,Malagasy ariary,MGA,2020-01-01,,MG
  Malawi,Kwacha,MWK,2020-01-01,,MW
  Malaysia,Ringgit,MYR,2020-01-01,,MY
  Maldives,Rufiyaa,MVR,2020-01-01,,MV
  Mali,West African CFA Franc,XOF,2020-01-01,,ML
  Mauritania,Ouguiya,MRU,2020-01-01,,MR
  Mauritius,Rupee,MUR,2020-01-01,,MU
  Mexico,Peso,MXN,2020-01-01,,MX
  Moldova,Leu,MDL,2020-01-01,,MD
  Mongolia,Tugrik,MNT,2020-01-01,,MN
  Montserrat,Eastern Caribbean dollar,XCD,2020-01-01,,MS
  Morocco,Dirham,MAD,2020-01-01,,MA
  Mozambique,Metical,MZN,2020-01-01,,MZ
  Myanmar,Kyat,MMK,2020-01-01,,MM
  Namibia,Dollar,NAD,2020-01-01,,NA
  Nepal,Rupee,NPR,2020-01-01,,NP
  Netherland Antilles (Curacao and Saint Maarten),Netherlands Antilles Guilder,ANG,2020-01-01,,AN
  New Caledonia,CFP Franc,XPF,2020-01-01,,NC
  New Zealand,Dollar,NZD,2020-01-01,,NZ
  Nicaragua,Córdoba,NIO,2020-01-01,,NI
  Niger,West African CFA Franc,XOF,2020-01-01,,NE
  Nigeria,Naira,NGN,2020-01-01,,NG
  North Korea,Won,KPW,2020-01-01,,KP
  North Macedonia,Denar,MKD,2020-01-01,,MK
  Norway,Krone,NOK,2020-01-01,,NO
  Oman,Rial,OMR,2020-01-01,,OM
  Pakistan,Rupee,PKR,2020-01-01,,PK
  Panama,Balboa,PAB,2020-01-01,,PA
  Papua New Guinea,Kina,PGK,2020-01-01,,PG
  Paraguay,Guaraní,PYG,2020-01-01,,PY
  Peru,Sol,PEN,2020-01-01,,PE
  Philippines,Peso,PHP,2020-01-01,,PH
  Poland,Złoty,PLN,2020-01-01,,PL
  Qatar,Riyal,QAR,2020-01-01,,QA
  Romania,Leu,RON,2020-01-01,,RO
  Russian Federation,Rouble,RUB,2020-01-01,,RU
  Rwanda,Franc,RWF,2020-01-01,,RW
  Saint Kitts and Nevis,Eastern Caribbean dollar,XCD,2020-01-01,,KN
  Saint Lucia,Eastern Caribbean dollar,XCD,2020-01-01,,LC
  Saint Vincent and the Grenadines,Eastern Caribbean dollar,XCD,2020-01-01,,VC
  Samoa,Tālā,WST,2020-01-01,,WS
  Sao Tome and Principe,Dobra,STN,2020-01-01,,ST
  Saudi Arabia,Riyal,SAR,2020-01-01,,SA
  Senegal,West African CFA Franc,XOF,2020-01-01,,SN
  Serbia,Dinar,RSD,2020-01-01,,XS
  Seychelles,Rupee,SCR,2020-01-01,,SC
  Sierra Leone,Leone,SLE,2020-01-01,,SL
  Singapore,Dollar,SGD,2020-01-01,,SG
  Solomon Islands,Dollar,SBD,2020-01-01,,SB
  Somalia,Shilling,SOS,2020-01-01,,SO
  South Africa,Rand,ZAR,2020-01-01,,ZA
  South Korea,Won,KRW,2020-01-01,,KR
  Sri Lanka,Rupee,LKR,2020-01-01,,LK
  Sudan,Pound,SDG,2020-01-01,,SD
  Suriname,Dollar,SRD,2020-01-01,,SR
  Sweden,Krona,SEK,2020-01-01,,SE
  Switzerland,Franc,CHF,2020-01-01,,CH
  Syria,Pound,SYP,2020-01-01,,SY
  Taiwan,Dollar,TWD,2020-01-01,,TW
  Tajikistan,Somoni,TJS,2020-01-01,,TJ
  Tanzania,Shilling,TZS,2020-01-01,,TZ
  Thailand,Baht,THB,2020-01-01,,TH
  Togo,West African CFA Franc,XOF,2020-01-01,,TG
  Tonga,Pa'anga,TOP,2020-01-01,,TO
  Trinidad and Tobago,Dollar,TTD,2020-01-01,,TT
  Tunisia,Dinar,TND,2020-01-01,,TN
  Turkey,Lira,TRY,2020-01-01,,TR
  Turkmenistan,Manat,TMT,2020-01-01,,TM
  Uganda,Shilling,UGX,2020-01-01,,UG
  Ukraine,Hryvnia,UAH,2020-01-01,,UA
  United Arab Emirates,Dirham,AED,2020-01-01,,AE
  United States,Dollar,USD,2020-01-01,,US
  Uruguay,Peso,UYU,2020-01-01,,UY
  Uzbekistan,Sum,UZS,2020-01-01,,UZ
  Vanuatu,Vatu,VUV,2020-01-01,,VU
  Venezuela,Bolivar Fuerte,VEF,2020-01-01,,VE
  Vietnam,Dong,VND,2020-01-01,,VN
  Wallis and Futuna,CFP Franc,XPF,2020-01-01,,WF
  Yemen,Rial,YER,2020-01-01,,YE
  Zambia,Kwacha,ZMW,2020-01-01,,ZM
  Zimbabwe,Dollar,ZWD,2020-01-01,,ZW
FILE

Sequel.migration do
  up do
    if ExchangeRateCountryCurrency.none?
      now = Time.zone.now

      CSV.parse(CSV_FILE, headers: true).each do |row|
        ExchangeRateCountryCurrency.create(
          row.to_h.merge(
            'created_at' => now,
            'updated_at' => now,
          ),
        )
      end
    end
  end

  down do
    # Won't rollback
  end
end
