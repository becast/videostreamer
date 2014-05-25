import Widget from require "lapis.html"

class HtmlLayout extends Widget
  content: =>
    html_5 ->
      head ->
        title ->
          if @title
            text @title .. " - Yukkuri Video Streamer"
          else
            text "Yukkuri Video Streamer"
        link rel: "stylesheet", href: "/css/style.css"
        if @has_content_for "script"
          script type: "application/javascript", src: "/js/jquery-1.11.0.js"
          @content_for "script"
      body ->
        div class: "header", ->
          div class: "right", ->
            a href: @url_for("play_index"), ->
              text "Home"
            if @user.name == "Anonymous"
              a href: @url_for("user_login"), ->
                text "Login"
              a href: @url_for("user_signup"), ->
                text "Signup"
            else
              a href: @url_for("user_profile"), ->
                text "Profile"
              a href: @url_for("user_logout"), ->
                text "Logout"
        @content_for "inner"

