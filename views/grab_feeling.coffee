debug = false
dbg = (a) ->
  console.log(a) if debug

add_system_log = (str) ->
  $("#system_log").append($("<p>").text(str))
  $("#system_log")[0].scrollTop = $("#system_log")[0].scrollHeight

add_chat_log = (name, message) ->
  p = $("<p>")
  p.text("#{name}: #{message}")
  p.html(p.text().replace(/((https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+))/, "<a href=\"$1\" target=\"_blank\">$1</a>"))
  $("#chat_log").append p
  $("#chat_log")[0].scrollTop = $("#chat_log")[0].scrollHeight

show_hide_drawing_tool = ->
  if canvas.drawing_allowed
    $(".drawing_tool").show()
  else
    $(".drawing_tool").hide()

room = undefined
remaining_to = undefined
canvas = undefined
context = undefined
drawing_option = {width: 3, color: '#2b2b2b', prev_colors: ['#2b2b2b']}
ws = undefined

add_player = (opt) ->
  name = opt.player_name || opt.name
  point = opt.player_point || opt.point
  player_id = opt.player_id || opt.id
  online = opt.online
  admin = opt.admin

  e = $tmp.player(".player_name": name,
                  ".point": point.toString())
  dbg e

  e.addClass('player')
  e.attr("id", "player#{player_id}")
  e.addClass('player_offline') unless online

  e[0].add_op = ->
    ws.puts type: "op", to: player_id if ws
  e[0].deop = ->
    ws.puts type: "deop", to: player_id if ws

  e.find(".add_op").click ->
    e.find(".add_op").hide()
    e.find(".deop").show()
    e[0].add_op()

  e.find(".deop").click ->
    e.find(".add_op").show()
    e.find(".deop").hide()
    e[0].deop()

  if admin
    e.find(".add_op").hide()
  else
    e.find(".deop").hide()

  # to be implemented
  #e.children(".kick").click e[0].deop

  $("#player_list").children("ul").append $("<li>").append(e)
  $("#cursors").append($("<div>").attr(id: "cursor#{player_id}", class: "cursor").text(name))

connect_websocket = ->
  add_system_log t('ui.connecting')
  ws = new WebSocket(room.websocket+"?player_id=#{room.player_id}&token=#{room.token}")
  ws.puts = (obj) ->
    dbg obj
    this.send JSON.stringify(obj)
  ws.onopen = (e) -> $("#chat_form input[type='submit']").removeAttr('disabled')
  ws.onmessage = (e) ->
    msg = JSON.parse(e.data)
    dbg msg
    switch msg.type
      when "image"
        draw_buffer = ->
          for buf in msg.buffer
            if buf.fill
              canvas.fill_background buf.fill
            else
              canvas.draw buf.from, buf.to, buf.option

          add_system_log t('ui.loaded')
          ws.puts type: "image_loaded"
          canvas.drawing_allowed = (room.player_id == room.drawer_id)
          show_hide_drawing_tool()

        if msg.clear
          draw_buffer()
        else
          image = new Image()
          image.onload = ->
            canvas.clear()

            context.drawImage(image, 0, 0, image.width, image.height)
            draw_buffer()

          image.src = msg.image
      when "empty_image"
        add_system_log t('ui.loaded')
        ws.puts type: "image_loaded"
        canvas.drawing_allowed = (room.player_id == room.drawer_id)
        show_hide_drawing_tool()
      when "image_request"
        dbg "Returning image"
        ws.puts type: "image", image: canvas.toDataURL("image/png")
      when "authorize_succeeded"
        add_system_log t('ui.connected')
        ws.send(JSON.stringify({type: "image_request"}))
      when "authorize_failed"
        add_system_log t('ui.authorize_failed')
      when "another_connected"
        add_system_log t('ui.another_connected')
      when "chat"
        add_chat_log msg.from, msg.message
      when "join"
        add_player msg
      when "leave"
        $("#player#{msg.player_id}").remove()
      when "system_log"
        add_system_log msg[room.locale]
      when "draw"
        unless room.player_id == msg.player_id
          if msg.fill
            canvas.fill_background msg.fill
          else
            $("#cursor#{msg.player_id}").css(top: msg.to.y, left: msg.to.x).show()
            canvas.draw msg.from, msg.to, msg.option
      when "image_requested"
        add_system_log t('ui.loading')
      when "clear"
        canvas.clear()
      when "topic"
        $("#topic").text(msg.topic)
      when "round"
        dbg msg
        canvas.drawing_allowed = (msg.drawer == room.player_id)
        show_hide_drawing_tool()
        remaining_to = Date.parse(msg.ends_at)
        canvas.clear()
      when "round_end"
        canvas.drawing_allowed = true
        show_hide_drawing_tool()
        remaining_to = Date.parse(msg.next_at)
      when "game_end"
        canvas.drawing_allowed = true
        remaining_to = undefined
        show_hide_drawing_tool()
      when "point"
        $("#player#{msg.player_id} .point").text(msg.point)
      when "online"
        $("#player#{msg.player_id}").removeClass('player_offline')
      when "offline"
        $("#player#{msg.player_id}").addClass('player_offline')
      when "op"
        if msg.player_id == room.player_id
          room.is_admin = true
          $(".admin_tool").show()
      when "deop"
        if msg.player_id == room.player_id
          room.is_admin = false
          $(".admin_tool").hide()
#      when "needs_token"
  ws.onerror = (e) ->
    add_system_log "Socket Error: #{e}"
    dbg e
  ws.onclose = (e) ->
    add_system_log "#{t('ui.closed')}: #{e}"
    dbg e

setup_canvas = ->
  canvas = $("#the_canvas")[0]
  r = canvas.getBoundingClientRect()
  context = canvas.getContext("2d")
  context.lineCap = "round"

  canvas.drawing = false
  canvas.drawing_allowed = false
  show_hide_drawing_tool()

  canvas.pointer = (e) ->
    {x: e.clientX - r.left, y: e.clientY - r.top}

  canvas.clear = ->
    context.clearRect(0, 0, canvas.width, canvas.height)

  canvas.fill_background = (color) ->
    context.fillStyle = color
    context.fillRect(0 ,0, canvas.width, canvas.height)

  canvas.draw = (from, to, option) ->
    context.strokeStyle = option.color || 'red'
    context.lineWidth = option.width || 1
    context.beginPath()
    context.moveTo(from.x, from.y)
    context.lineTo(to.x, to.y)
    context.stroke()

  $(canvas).mousedown (e) ->
    canvas.drawing = true
    canvas.old_point = canvas.pointer(e)

  $(canvas).mousemove (e) -> if ws && canvas.drawing && canvas.drawing_allowed
    point = canvas.pointer(e)
    ws.puts type: "draw", from: canvas.old_point, to: point, option: drawing_option
    canvas.draw canvas.old_point, point, drawing_option
    canvas.old_point = point

  $(canvas).bind 'touchstart', (e) ->
    e.preventDefault()
    canvas.drawing = true
    canvas.old_point = canvas.pointer(event.changedTouches[0])

  $(canvas).bind 'touchmove', (e) -> if ws && canvas.drawing && canvas.drawing_allowed
      point = canvas.pointer(event.changedTouches[0])
      dbg point
      ws.puts type: "draw", from: canvas.old_point, to: point, option: drawing_option
      canvas.draw canvas.old_point, point, drawing_option
      canvas.old_point = point

  drawed = (e) ->
    $("#chat_field").focus()
    canvas.drawing = false
  $(canvas).mouseup drawed
  $(canvas).mouseout drawed
  $(canvas).bind 'touchend', drawed

$(document).ready ->
  setup_canvas()

  add_system_log t('ui.retriving_data')

  $("#start_button").hide()

  $("#chat_form").submit (e) ->
    e.preventDefault()
    if $("#chat_field").val().length > 0 && ws
      ws.puts type: "chat", message: $("#chat_field").val()
      $("#chat_field").val("")

  #colors = ["e60033", "007b43", "6f4b3e", "a0d8ef", "1e50a2", "ee7800", "65318e", "98d98e", "00552e", "2b2b2b", "ffd900", "f0908d", "000000", "c0c0c0", "ffffff"]
  colors = ["e60033", "f0908d", "ee7800", "ffd900", "98d98e", "007b43", "00552e", "a0d8ef", "1e50a2", "65318e", "6f4b3e", "c0c0c0", "2b2b2b", "ffffff"]
  for color in colors
    container = $("<div>").addClass('color_button_container')
    container.append $("<div>").css('background-color', "##{color}") \
                                 .attr('id', "color_#{color}") \
                                 .addClass('color_button')
    $("#colors").append container

  $("#color_2b2b2b").parent().addClass('color_selected')

  color_select = (e) ->
    $(".color_selected").removeClass('color_selected')
    drawing_option.prev_colors.unshift drawing_option.color
    drawing_option.color = $(e.target).attr('id').replace('color_','#')
    $(e.target).parent().addClass('color_selected')

  $("div.color_button").click color_select

  $("div.color_button").dblclick (e) ->
    color = $(e.target).attr('id').replace('color_','#')
    color_select target: $("#color_#{drawing_option.prev_colors[2].replace('#','')}")[0]
    drawing_option.prev_colors = [drawing_option.color]
    if canvas.drawing_allowed
      canvas.fill_background color
      ws.puts type: "draw", fill: color

  $(".width_button").each (i,v) -> $(v).click ->
    drawing_option.width = $(v).attr('id').replace('width_','')

  $("#clear_button").click ->
    ws.puts type: "clear" if canvas.drawing_allowed

  $("#snapshot").click ->
    window.open(canvas.toDataURL("image/png"))

  $("#start_button").click -> if ws && room.is_admin
    ws.puts type: "start"

  $.getJSON("#{location.pathname}.json", (data) ->
    room = data

    debug = room.debug

    if room.error
      add_system_log "Error: #{room.error}"
      return

    if room.system_logs
      for log in room.system_logs
        add_system_log log[room.locale]

    if room.logs
      for log in room.logs
        add_chat_log log.name, log.message

    if room.topic
      $("#topic").text room.topic

    #canvas.drawing_allowed = (room.player_id == room.drawer_id)

    if room.players
      add_player player for player in room.players

    if room.ends_at
      remaining_to = Date.parse(room.ends_at)
    if room.next_at
      remaining_to = Date.parse(room.next_at)

    $(".admin_tool").show() if room.is_admin


    hide_cursor = ->
      $(".cursor").hide()
    setInterval(hide_cursor, 1000)

    remaining_timer = ->
      if remaining_to
        now = new Date
        to = new Date
        to.setTime remaining_to
        diff = Math.round((to-now) / 1000)
        dbg diff
        min = Math.floor(diff / 60).toString()
        sec = Math.round(diff % 60).toString()
        min = "0" + min if min.length == 1
        sec = "0" + sec if sec.length == 1
        remain = "#{min}:#{sec}"
        $("#remaining_timer").text(remain)
      else
        $("#remaining_timer").text('--:--')
    setInterval(remaining_timer, 500)

    pong_timer = ->
      ws.puts type: "ping" if ws
    setInterval pong_timer, 5000

    dbg room

    connect_websocket()
  ).error((xhr, text, e) -> add_system_log "oops? #{text} - #{e}")

