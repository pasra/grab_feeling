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
drawing_option = {width: 3, color: 'black'}
ws = undefined

add_player = (player_id, name, point) ->
  $("#player_list").append $("<span>").attr('id',"player#{player_id}") \
                                      .text(name+"(") \
                                      .append($("<span>").addClass('point') \
                                                         .text(point)).append(")")

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
          draw buf.from, buf.to, buf.option for buf in msg.buffer
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
      when "chat"
        add_chat_log msg.from, msg.message
      when "join"
        add_player msg.player_id, msg.player_name, msg.player_point
      when "leave"
        $("#player#{msg.player_id}").remove()
      when "system_log"
        add_system_log msg[room.locale]
      when "draw"
        unless room.player_id == msg.player_id
          canvas.draw msg.from, msg.to, msg.option
      when "image_requested"
        add_system_log t('ui.loading')
      when "clear"
        canvas.clear()
      when "topic"
        $("#topic").text(msg.topic)
      when "round"
        dbg msg
        if msg.drawer != room.player_id
          canvas.drawing_allowed = false
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
#      when "needs_token"
  ws.onerror = (e) ->
    add_system_log "Socket Error: #{e}"
    dbg e
  ws.onclose = (e) ->
    add_system_log "#{t('ui.closed')}: #{e}"
    dbg e

setup_canvas = ->
  canvas = $("#the_canvas")[0]
  context = canvas.getContext("2d")
  context.lineCap = "round"

  canvas.drawing = false
  canvas.drawing_allowed = false
  show_hide_drawing_tool()

  canvas.pointer = (e) ->
    r = this.getBoundingClientRect()
    {x: e.clientX - r.left, y: e.clientY - r.top}

  canvas.clear = ->
    context.clearRect(0, 0, canvas.width, canvas.height)

  canvas.draw = (from, to, option) ->
    context.strokeStyle = option.color || 'red'
    context.lineWidth = option.width || 1
    context.beginPath()
    context.moveTo(from.x, from.y)
    context.lineTo(to.x, to.y)
    context.stroke()
    #context.closePath()

  $(canvas).mousedown (e) ->
    canvas.drawing = true
    canvas.old_point = canvas.pointer(e)
    dbg canvas.drawing_allowed

  $(canvas).mousemove (e) -> if ws && canvas.drawing && canvas.drawing_allowed
    point = canvas.pointer(e)
    ws.puts type: "draw", from: canvas.old_point, to: point, option: drawing_option
    canvas.draw canvas.old_point, point, drawing_option
    canvas.old_point = point

  drawed = -> canvas.drawing = false
  $(canvas).mouseup drawed
  $(canvas).mouseout drawed

$(document).ready ->
  setup_canvas()

  add_system_log t('ui.retriving_data')

  $("#start_button").hide()

  $("#chat_form").submit ->
    if ws
      ws.puts type: "chat", message: $("#chat_field").val()
      $("#chat_field").val("")
    false

  colors = ["e60033", "007b43", "6f4b3e", "a0d8ef", "1e50a2", "ee7800", "65318e", "98d98e", "00552e", "2b2b2b", "ffd900", "f0908d", "000000", "ffffff"]
  for color in colors
    container = $("<div>").addClass('color_button_container')
    container.append $("<div>").css('background-color', "##{color}") \
                                 .attr('id', "color_#{color}") \
                                 .addClass('color_button')
    $("#colors").append container

  $("#color_000000").parent().addClass('color_button_container')

  $("div.color_button").click (e) ->
    $(".color_selected").removeClass('color_selected')
    drawing_option.color = $(e.target).attr('id').replace('color_','#')
    $(e.target).parent().addClass('color_selected')

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

    if room.player_id != room.drawer_id
      canvas.drawing_allowed = false
      show_hide_drawing_tool()

    if room.players
      add_player(player.id, player.name, player.point) for player in room.players

    if room.ends_at
      remaining_to = Date.parse(room.ends_at)
    if room.next_at
      remaining_to = Date.parse(room.next_at)

    $("#start_button").show() if room.is_admin

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

    debug = room.debug
    dbg room

    connect_websocket()
  ).error((xhr, text, e) -> add_system_log "oops? #{text} - #{e}")

