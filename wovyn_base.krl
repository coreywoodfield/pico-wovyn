ruleset wovyn_base {
  meta {
    use module sensor_profile
    use module io.picolabs.subscription alias subs
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
    if (event:attr("temperature").any(function(x){
      x{"temperatureF"} > sensor_profile:query{"threshold"}
    })) then
      send_directive("say", "High temp found")
    fired {
      raise wovyn event "threshold_violation" attributes event:attrs
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      manager = subs:established("Tx_role", "manager").first()
    }
    event:send({
      "eci": manager{"Tx"},
      "eid": "threshold_violation",
      "domain": "manager_profile",
      "type": "threshold_violation",
      "attrs": {}
    })
  }
}
