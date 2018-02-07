ruleset wovyn_base {
  global {
    temperature_threshold = 72
  }

  rule process_heartbeat {
    select when wovyn heartbeat
    if (event:attr("genericThing") != null) then
      send_directive("say", {})
    fired {
      raise wovyn event "new_temperature_reading" attributes {
        "temperature": event:attr("genericThing"){"data"}{"temperature"},
        "timestamp": time:now()
      }
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    if (event:attr("temperature")) then
      send_directive("say", "High temp found")
    fired {
      raise wovyn event "threshold_violation" attributes event:attrs()
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
  }
}
