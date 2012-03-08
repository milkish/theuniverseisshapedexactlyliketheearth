task :default do
  base_dir   = File.expand_path '../', __FILE__
  build_dir  = base_dir + "/build/"

  `mkdir -p #{build_dir}`
  `cp application.css #{build_dir}application.css`
  `coffee -c application.coffee`

  script_urls = []
  new_haml    = ""
  f = File.open "index.haml", 'r'
  f.lines.each do |line|
    # match a script tag with a src, then grab the src
    # and disgard the line
    if line.match /(%script.*src:)[^"]*"([^"]*)/
      script_urls << $~[2]
    else
      new_haml << line
      # insert the haml for the minified js
      if line.match /(\s*)%head/
        # set the appropriate indentation
        new_haml << ($~[1] * 2)
        new_haml << "%script{ src: \"application.min.js\"}\n"
      end
    end
  end
  File.open 'intermediate.haml', 'w' do |f|
    f.write new_haml
  end
  `haml intermediate.haml #{build_dir}index.html`
  `rm intermediate.haml`

  script_txt = ""
  script_urls.each_with_index do |url, i|
    url['://'] ? `wget #{url} -O #{i}.js`
               : `cp #{url} #{i}.js`
    `uglifyjs --overwrite #{i}.js`
    File.open "#{i}.js", 'r' do |f|
      script_txt << "//#{url}\n"
      script_txt << f.read
      script_txt << "\n\n"
    end
    `rm #{i}.js`
  end
  File.open "#{build_dir}application.min.js", 'w' do |f|
    f.write script_txt
  end
end