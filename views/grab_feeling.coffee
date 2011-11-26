debug = false
dbg = (a) ->
  console.log(a) if debug

add_system_log = (str) -> $("#system_log").append($("<p>").text(str))
add_chat_log = (name, message) -> $("#chat_log").append($("<p>").text("#{name}: #{message}"))

room = undefined
canvas = undefined
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
        add_system_log t('ui.loaded')
        ws.puts type: "image_loaded"
        canvas.drawing_allowed = true
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
        dbg msg
      when "leave"
        dbg msg
      when "system_log"
        add_system_log msg[room.locale]
      when "draw"
        dbg msg
      when "image_requested"
        add_system_log t('ui.loading')
#      when "needs_token"
  ws.onerror = (e) ->
    add_system_log "Socket Error: #{e}"
    dbg e
  ws.onclose = (e) ->
    add_system_log "#{t('ui.closed')}: #{e}"
    dbg e

setup_canvas = ->
  canvas = $("#the_canvas")[0]

  canvas.drawing = false
  canvas.drawing_allowed = false

  canvas.pointer = (e) ->
    r = this.getBoundingClientRect()
    {x: e.clientX - r.left, y: e.clientY - r.top}

  canvas.draw = (from, to, option) ->
    context = canvas.getContext("2d")
    context.strokeStyle = option.color || 'red'
    context.lineWidth = option.width || 1
    context.beginPath()
    context.moveTo(from.x, from.y)
    context.lineTo(to.x, to.y)
    context.stroke()
    context.closePath()

  $(canvas).mousedown (e) ->
    canvas.drawing = true
    canvas.old_point = canvas.pointer(e)

  $(canvas).mousemove (e) -> if ws && canvas.drawing && canvas.drawing_allowed
    point = canvas.pointer(e)
    canvas.draw(canvas.old_point, point, width: 3, color: 'black')
    canvas.old_point = point

  drawed = -> canvas.drawing = false
  $(canvas).mouseup drawed
  $(canvas).mouseout drawed

$(document).ready ->
  setup_canvas()

  add_system_log t('ui.retriving_data')

  $("#chat_form").submit ->
    if ws
      ws.puts type: "chat", message: $("#chat_field").val()
      $("#chat_field").val("")
    false

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

    debug = data.debug
    room = data
    dbg data

    connect_websocket()
  ).error((xhr, text, e) -> add_system_log "oops? #{text} - #{e}")

