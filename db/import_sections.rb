sections = [
  { position: 1, numeral: 'I',     title: 'Live animals; animal products', chapters: ('01'..'05') },
  { position: 2, numeral: 'II',    title: 'Vegetable products', chapters: ('06'..'14') },
  { position: 3, numeral: 'III',   title: 'Animal or vegetable fats and oils and their cleavage products; prepared edible fats; animal or vegetable waxes', chapters: ('15'..'15') },
  { position: 4, numeral: 'IV',    title: 'Prepared foodstuffs; beverages, spirits and vinegar; tobacco and manufactured tobacco substitutes', chapters: ('16'..'24') },
  { position: 5, numeral: 'V',     title: 'Mineral products', chapters: ('25'..'27') },
  { position: 6, numeral: 'VI',    title: 'Products of the chemical or allied industries', chapters: ('28'..'38') },
  { position: 7, numeral: 'VII',   title: 'Plastics and articles thereof; rubber and articles thereof', chapters: ('39'..'40') },
  { position: 8, numeral: 'VIII',  title: 'Raw hides and skins, leather, furskins and articles thereof; saddlery and harness; travel goods, handbags and similar containers; articles of animal gut (other than silkworm gut)', chapters: ('41'..'43') },
  { position: 9, numeral: 'IX',    title: 'Wood and articles of wood; wood charcoal; cork and articles of cork; manufactures of straw, of esparto or of other plaiting materials; basket-ware and wickerwork', chapters: ('44'..'46') },
  { position: 10, numeral: 'X',    title: 'Pulp of wood or of other fibrous cellulosic material; recovered (waste and scrap) paper or paperboard; paper and paperboard and articles thereof', chapters: ('47'..'49') },
  { position: 11, numeral: 'XI',   title: 'Textiles and textile articles', chapters: ('50'..'63') },
  { position: 12, numeral: 'XII',  title: 'Footwear, headgear, umbrellas, sun umbrellas, walking-sticks, seat-sticks, whips, riding-crops and parts thereof; prepared feathers and articles made therewith; artificial flowers; articles of human hair', chapters: ('64'..'67') },
  { position: 13, numeral: 'XIII', title: 'Articles of stone, plaster, cement, asbestos, mica or similar materials; ceramic products; glass and glassware', chapters: ('68'..'70') },
  { position: 14, numeral: 'XIV',  title: 'Natural or cultured pearls, precious or semi-precious stones, precious metals, metals clad with precious metal and articles thereof; imitation jewellery; coins', chapters: ('71'..'71') },
  { position: 15, numeral: 'XV',   title: 'Base metals and articles of base metal', chapters: ('72'..'83') },
  { position: 16, numeral: 'XVI',  title: 'Machinery and mechanical appliances; electrical equipment; parts thereof, sound recorders and reproducers, television image and sound recorders and reproducers, and parts and accessories of such articles', chapters: ('84'..'85') },
  { position: 17, numeral: 'XVII', title: 'Vehicles, aircraft, vessels and associated transport equipment', chapters: ('86'..'89') },
  { position: 18, numeral: 'XVIII', title: 'Optical, photographic, cinematographic, measuring, checking, precision, medical or surgical instruments and apparatus; clocks and watches; musical instruments; parts and accessories thereof', chapters: ('90'..'92') },
  { position: 19, numeral: 'XIX',  title: 'Arms and ammunition; parts and accessories thereof', chapters: ('93'..'93') },
  { position: 20, numeral: 'XX',   title: 'Miscellaneous manufactured articles', chapters: ('94'..'96') },
  { position: 21, numeral: 'XXI',  title: "Works of art, collectors' pieces and antiques", chapters: ('97'..'99') },
]

sections.each do |sec|
  Section.insert(
    title: sec[:title],
    numeral: sec[:numeral],
    position: sec[:position],
    created_at: Time.zone.now,
    updated_at: Time.zone.now,
  )
end

# Map chapters to sections
Chapter.all.each do |chapter|
  sp = sections.select { |v| (v[:chapters]).include?(chapter.short_code) }
  section_position = sp.first[:position]
  section = Section.where(position: section_position).take
  chapter.remove_all_sections
  chapter.add_section section
end
