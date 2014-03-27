require! <[fs request]>

if process.argv < 3 =>
  console.log "usage: lsc download.ls [comic-url]"
  process.exit!

comic-name = /\/([^\/]+)\/$/.exec process.argv.2
if !comic-name =>
  console.log "#{config.book-url}: url malformat. "
  phantom.exit!
comic-name = comic-name.1

config =  JSON.parse(fs.read-file-sync "data/#{comic-name}/config.json" .toString!)

hash = {}
all-pages = {}

expand = ->
  result = {}
  for idx,list of hash
    idx = (if idx.length < 4 => ("0" * ((4 - idx.length )>?0)) else "") + idx
    for v in list
      ret = /\/([^_./]+)[^/]+$/.exec v
      if not ret => continue
      p = ret.1
      k = "#{idx}-#{p}"
      result[k] = v
  result

download = ->
  list = [[k,v] for k,v of all-pages]
  while true
    if list.length==0 => 
      console.log "all download complete."
      return
    [k,v] = list.0
    if fs.exists-sync "data/#{comic-name}/img/#k.png" => 
      list.splice 0,1
      delete all-pages[k]
    else break
  console.log "downloading #k / #v "
  try
    request "#{config.base-url}#v" .pipe fs.create-write-stream "data/#{comic-name}/img/#k.png"
  catch
    console.log "#k failed, retry."
    return set-timeout (-> download!), 100
  delete all-pages[k]
  set-timeout (-> download!), 100
    
each-chapter = (idx) ->
  c = config.chapters[idx]
  ret = /\/([^/]+)\/$/.exec c
  if not ret => return
  chapter = ret.1
  ret = /^([^0-9]+)/.exec chapter
  prefix = if ret => ret.1 else ""
  js = "#{config.base-url}/Utility/#{config.id}/#{if prefix => "#prefix/" else ""}#{chapter}.js"
  #console.log js
  console.log "fetching #c pages"
  request js, (e,v,b) ->
    files = b.split(\;)filter(->it)map(-> ((/\]\s*=\s*"([^"]+)"/.exec it) or [null,null]).1)filter(->it)
    console.log "#c : total #{files.length} pages."
    hash[chapter] = files
    idx++
    if idx < config.chapters.length => set-timeout -> each-chapter idx
    else
      fs.write-file-sync "data/#{comic-name}/pages.json", JSON.stringify hash
      all-pages := expand!
      download!

if !fs.exists-sync "data/#{comic-name}/img/" => fs.mkdir-sync "data/#{comic-name}/img/"
if fs.exists-sync "data/#{comic-name}/pages.json" =>
  console.log "previous fetch found, ignore page list fetching."
  hash = JSON.parse fs.read-file-sync "data/#{comic-name}/pages.json"
  all-pages := expand!
  download!
else
  each-chapter 0
