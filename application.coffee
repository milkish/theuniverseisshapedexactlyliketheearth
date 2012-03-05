# constants
API_KEY         = "986337bb73dd45ce5a470f6cdf9dbafa"
DEFAULT_USER    = "milkish"
PHOTOS_PER_PAGE = 20

# some convenience aliases
wndw = $(window)
dispatch = (event_name, params = {}) ->
  wndw.trigger event_name, params
on_event = (event_name, callback) ->
  wndw.bind event_name, callback
unbind = (event_name, callback) ->
  wndw.unbind event_name, callback

is_def = (obj) -> 
  typeof(obj) != "undefined"

# Data Management
class Flickr
  api_get: (method, params, successCB) ->
    url = "http://api.flickr.com/services/rest/?" + 
          "method=#{method}" +
          "&api_key=#{API_KEY}&format=json&nojsoncallback=1" +
    url+= "&#{key}=#{val}" for key, val of params
    $.ajax
      url: url,
      dataType: "JSON"
      success: (data) ->
        if data.stat == "ok"
          successCB data
        if data.stat != "ok"
          alert "something went wrong. :("

class Photo
  constructor: (@_id, @title) ->
    @ready     = false
    @index     = undefined
    @flickr    = new Flickr
    @size_data = []
    @get_sizes()

  get_sizes: ->
    @flickr.api_get "flickr.photos.getSizes", {photo_id:@_id}, (data) =>
      @size_data = data.sizes.size
      @ready = true
      dispatch "PhotoReady", this

  biggest: ->
    {url: @size_data[@size_data.length-1].source}

  display: ->
    _sizes = (@size_data[0...@size_data.length]).reverse()
    for size in _sizes
      return {url: size.source} if size.width < 1500

class PhotoColection
  constructor: (@photos = []) ->

  push: (new_photo) ->
    new_photo.index = @photos.length
    @photos.push new_photo
  count: ->
    @photos.length

class FlickrUser
  constructor: (@user_url, ready_callback) ->
    @_id         = undefined
    @flickr      = new Flickr
    @photos      = new PhotoColection()
    @username    = undefined
    @getting_photos    = false
    @all_photos_gotten = false
    @get_user_id @username, (data) =>
      @_id      = data.user.id
      @username = data.user.username["_content"]
      ready_callback()

  get_user_id: (name, cB) ->
    @flickr.api_get "flickr.urls.lookupUser", {url:"http://www.flickr.com/photos/#{@user_url}"}, cB

  get_more_photos: (cB) ->
    return false if @all_photos_gotten or @getting_photos
    app_model.loading(true)
    @getting_photos = true
    page = @photos.count() / PHOTOS_PER_PAGE + 1
    params = {user_id: @_id, per_page: PHOTOS_PER_PAGE, page: page }
    @flickr.api_get "flickr.people.getPublicPhotos", params, (data) =>
      @getting_photos = false
      @photos.push new Photo(raw_photo.id, raw_photo.title) for raw_photo in data.photos.photo
      no_more_photos() if data.photos.photo.length == 0 or @photos.count() % PHOTOS_PER_PAGE != 0
      cB() if cB

  no_more_photos: ->
    @all_photos_gotten = true
    dispatch("EndOfPhotos")

# Vars
user          = undefined
lb            = undefined
current_photo = -1
next_photo    = undefined
slide_height  = 0
scroll_override = false
tmp_photo_hldr  = [] # storage for photos as they load

# Helpers
up_photo = ->
  scroll_to_photo( if is_def next_photo then next_photo-1 else current_photo-1 )
down_photo = ->
  scroll_to_photo( if is_def next_photo then next_photo+1 else current_photo+1 )

scroll_to_photo = (index,cB) =>
  return false unless -1 < index < app_model.photos().length
  next_photo = index
  lb.stop(true,false).animate {"scrollTop": index * wndw.height()}, 250, "swing", =>
    next_photo = undefined
    cB() if cB

init_display = ->
  if current_photo == -1  and app_model.photos().length > 0
    unbind "PhotoReady", init_display
    lb.trigger "scroll" 
    scroll_to_photo 0
    show_instructions()

show_instructions = ->
  $("#instructions").fadeIn("slow")
  setTimeout hide_instructions, 5000
  on_event "lbScroll", hide_instructions
  on_event "keydown", hide_instructions

hide_instructions = ->
  unbind "lbScroll", hide_instructions
  unbind "keydown", hide_instructions
  $("#instructions").fadeOut("fast")

launch_photo = ->
  _url = app_model.photos()[current_photo].biggest().url 
  window.open _url,'_blank'

# Keyboard Overrides
key_overrides = 
  37: up_photo     #left
  39: down_photo   #right
  38: up_photo     #up
  40: down_photo   #down
  13: launch_photo #enter

# Event Handlers

on_event "keydown", (e) ->
  return true if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
  key = Number e.which
  if (key_overrides[key])
    key_overrides[key]()
    e.preventDefault()
    false

on_event "PhotoReady", (event, photo)->
  tmp_photo_hldr[photo.index] = photo
  num_photos = app_model.photos().length
  while tmp_photo_hldr[num_photos]
    app_model.photos.push tmp_photo_hldr[num_photos]
    tmp_photo_hldr[num_photos] = undefined
    num_photos++

  app_model.loading(false) if app_model.photos().length == user.photos.count()

on_event "PhotoReady", init_display

on_event "EndOfPhotos", ->
  # alert "no more photos to load"

on_event "PhotoChange", =>
  $(".current_photo").removeClass "current_photo"
  $($(".photo").get(current_photo)).addClass "current_photo"
  app_model.title(app_model.photos()[current_photo].title)
  return unless user
  if current_photo > user.photos.count() - 5
    user.get_more_photos()

on_event "lbScroll", (event, orig_event) ->
  _st = orig_event.currentTarget.scrollTop
  _photo = Math.floor( (_st + slide_height/2 ) / slide_height )
  unless current_photo == _photo
    current_photo = _photo
    dispatch "PhotoChange"

on_event "hashchange", ->
  window.location.reload()

# Application Script
KoModel = ->
  photos:   ko.observableArray []
  username: ko.observable()
  title:    ko.observable('')
  loading:  ko.observable(false)
app_model = new KoModel()

on_event "resize", ->
  slide_height = wndw.height()
  scroll_to_photo current_photo

initialize = (_username) ->
  lb = $ "#light-box"
  dispatch "resize"
  lb.on "scroll", (e) -> dispatch "lbScroll", e
  $('.photo').live "click", ->
    # same as launch_photo but here to avoid popup blockers
    _url = app_model.photos()[current_photo].display().url 
    window.open _url,'_blank'
    scroll_to_photo $(this).data('index')
  ko.applyBindings app_model
  # app_model.username _username
  app_model.photos([])
  user = new FlickrUser _username, ->
    app_model.username user.username
    user.get_more_photos()


# kick it off on dom load
$ -> initialize window.location.hash.replace(/#/, '') || "milkish"