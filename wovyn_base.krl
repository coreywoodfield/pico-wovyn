ruleset wovyn_base {
  rule process_heartbeat {
    select when wovyn heartbeat
    if (event:attr("genericThing") != null) then {
      send_directive("say", {})
    }
  }
}
