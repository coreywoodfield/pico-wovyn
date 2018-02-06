ruleset wovyn_base {
  rule process_heartbeat {
    select when wovyn heartbeat
    send_directive("say", {})
  }
}
