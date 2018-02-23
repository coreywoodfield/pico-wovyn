ruleset wovyn_base {
  meta {
    use module keys
    use module sensor_profile
    use module twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
  }

  global {
    from = "not a real number"
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
    twilio:send_sms(sensor_profile:query{"number"}, from, "Temperature over defined threshold")
  }
}
