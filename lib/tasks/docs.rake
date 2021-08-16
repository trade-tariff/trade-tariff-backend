namespace :doc do
  desc 'Collect live API responses for docs'
  task api: 'environment' do
    File.open("#{Rails.root}/app/views/home/docs/_sections.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/sections').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_sections_1.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/sections/1').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_chapter.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/chapters/01').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_heading.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/headings/0101').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_commodity.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/commodities/010130000080').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_import_measures.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/commodities/010130000080/import_measures').read))
    end
    File.open("#{Rails.root}/app/views/home/docs/_export_measures.html.erb", 'w') do |f|
      f << JSON.pretty_generate(JSON.parse(open('http://localhost:3018/commodities/010130000080/export_measures').read))
    end
  end
end
