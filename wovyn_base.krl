ruleset wovyn_base {
  rule process_heartbeat {
    select when wovyn heartbeat
    if (event:attr("genericThing") != null) then
      send_directive("say", {})
    fired {
      raise wovyn event "new_temperature_reading"
        attributes {"temperature": event:attr("genericThing"){"data"}{"temperature"}, "timestamp": time:now()}
    }
  }
}
