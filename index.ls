require! <[fs system]>

if system.args.length < 2 =>
  console.log "usage: lsc crawler.ls [url-to-comic-index-page]"
  console.log "  e.g., lsc crawler.ls http://comic.sfacg.com/HTML/LNBFB/"
  phantom.exit(0)

config = do
  base-url: \http://comic.sfacg.com/
  # example: \http://comic.sfacg.com/HTML/LNBFB/
  book-url: system.args.1
  chapters: []
  chapter: {}
  idx: c: 0, p: 1

comic-name = /\/([^\/]+)\/$/.exec config.book-url
if !comic-name =>
  console.log "#{config.book-url}: url malformat. "
  phantom.exit!
comic-name = comic-name.1

new-page = ->
  page = require \webpage .create!
    ..settings.resourceTimeout = 3000
    ..on-console-message = -> 
    ..on-error = ->

get-images = (config) ->
  chapter-url = config.chapters[config.idx.c]
  url = "#{config.base-url}/#{config.chapters[config.idx.c]}/?p=#{config.idx.p}"
  console.log "parse url for image: #url"
  page = new-page!
  page.open url, ->
    page.inject-js \jquery.min.js
    src = page.evaluate -> $(\#curPic)0.get-attribute \src
    console.log "image url: #src"
    config.chapter[config.idx.c].[]img.push src
    #setTimeout (-> page.close!), 0
    config.idx.p++
    if config.idx.p > config.chapter[config.idx.c].pages =>
      config.idx.c++
      config.idx.p = 1
      if config.idx.c >= config.chapters.length =>
        fs.write "data/#{comic-name}/config.json", JSON.stringify(config), \w
        phantom.exit!
      else setTimeout (-> get-pages config), 100
    else setTimeout (-> get-images config), 100

get-pages = (config) ->
  #fs.write "data/#{comic-name}/config.json", JSON.stringify(config), \w
  chapter-url = config.chapters[config.idx.c]
  config.chapter.{}[config.idx.c].name = chapter-url
  url = "#{config.base-url}#chapter-url"
  console.log ">>> fetching chapter: #chapter-url (#url)"
  page = new-page!
  page.open url, ->
    page.inject-js \jquery.min.js
    pages = page.evaluate -> $('#pageSel option')length
    console.log "chapter #chapter-url : total #pages pages"
    config.chapter.{}[config.idx.c].pages = pages
    config.idx.p = 1
    set-timeout (-> page.close!), 0
    set-timeout (-> get-images config), 100


get-chapters = (config) ->
  console.log "open #{config.book-url} for chapter listing"
  page = new-page!
  page.open config.book-url, ->
    page.inject-js \jquery.min.js
    [chapters,id] = page.evaluate ->
      list = $('.serialise_list li a')
      ret = for i from 0 til list.length => list[i]get-attribute \href
      [ret, comicCounterID]
    console.log "#{comic-name} comic id: #id, estimate #{chapters.length} chapters"
    config{chapters,id} = {chapters, id} 
    config.idx.c = 0
    fs.write "data/#{comic-name}/config.json", JSON.stringify(config), \w

    # now stop here. we dont need phantomjs to scrape every single image
    phantom.exit!

    set-timeout (-> page.close!), 0
    set-timeout (-> get-pages config), 100

if !fs.exists \data => fs.mkdir \data
if !fs.exists "data/#{comic-name}" => fs.mkdir "data/#{comic-name}"
if !fs.exists("data/#{comic-name}/config.json") => get-chapters config
else phantom.exit!
