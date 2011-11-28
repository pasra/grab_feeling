debug = false
dbg = (a) ->
  console.log(a) if debug

add_system_log = (str) ->
  $("#system_log").append($("<p>").text(str))
  $("#system_log")[0].scrollTop = $("#system_log")[0].scrollHeight

add_chat_log = (name, message) ->
  $("#chat_log").append($("<p>").text("#{name}: #{message}"))
  $("#chat_log")[0].scrollTop = $("#chat_log")[0].scrollHeight

room = undefined
canvas = undefined
context = undefined
drawing_option = {width: 3, color: 'black'}
ws = undefined

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
          canvas.drawing_allowed = true

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
        canvas.drawing_allowed = true
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
        $("#player_list p").append("<span id=#{msg.player_id}>#{msg.player_name}(#{msg.point}) </span>")
        dbg msg
      when "leave"
        $("##{msg.player_id}").remove()
        dbg msg
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
        if drawer != room.player_id
          canvas.drawing_allowed = false
      when "round_end"
        canvas.drawing_allowed = true
      when "game_end"
        canvas.drawing_allowed = true
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

  $("input.color_button").each (i,v) -> $(v).click ->
    drawing_option.color = $(v).attr('id').replace('color_','')

  $(".width_button").each (i,v) -> $(v).click ->
    drawing_option.width = $(v).attr('id').replace('width_','')

  $("#clear_button").click ->
    ws.puts type: "clear"

  $("#snapshot").click ->
    window.open(canvas.toDataURL("image/png"))

  $("#start_button").click -> if ws && room.is_admin
    ws.puts type: "start"

  $.getJSON("#{location.pathname}.json", (data) ->
    if data.error
      add_system_log "Error: #{data.error}"
      return
    if data.system_logs
      for log in data.system_logs
        add_system_log log[data.locale]
    if data.logs
      for log in data.logs
        add_chat_log log.name, log.message

    $("#start_button").show() if data.is_admin

    debug = data.debug
    room = data
    dbg data

    player_list = $("#player_list p")
    jQuery.each(room.players, (i, player) ->
      player_list.append("<span id=#{player.id}>#{player.name}(#{player.point}) </span>")
    )

    connect_websocket()
  ).error((xhr, text, e) -> add_system_log "oops? #{text} - #{e}")

