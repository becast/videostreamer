import Widget from require "lapis.html"

class extends Widget
  content: =>
    @content_for "title", "Index"
    div class: "root-container", ->
      div class: "inner-container", ->
        div class: "fancybox", ->
          h1 "Running streams:"
          if @streams
              ul ->
              for appname,v in pairs @streams
                for stream in *v
                  li ->
                    base = "#{@http_base}/#{appname}/#{stream.name}"
                    rtmpbase = "#{@rtmp_base}/#{appname}/#{stream.name}"
                    text "[ "
                    a href: base, ->
                      text "#{appname}/#{stream.name}"
                    text " ] [ "
                    a href: "#{base}?buffer=0", ->
                      text "unbuffered"
                    text " ] [ "
                    a href: "#{base}?buffer=10.0", ->
                      text "buffered for 10 seconds"
                    text " ] [ "
                    a href: "#{rtmpbase}", ->
                      text "direct rtmp url"
                    text " ] author: " .. stream.username .. " ( "
                    image_source = "http://www.gravatar.com/avatar/"
                    image_source ..= stream.hash .. "?d=identicon&s=32"
                    img src: image_source, alt: stream.hash
                    text " )"


          else
            div ->
              text "Sorry, no streams running :/"