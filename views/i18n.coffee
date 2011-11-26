window.t = (id) ->
  paths = id.split(".")
  obj = window.localization
  for path in paths
    obj = obj[path]
    if !obj
      obj = "Translation missing: #{id}"
      break
  obj
