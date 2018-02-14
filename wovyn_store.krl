ruleset temperature_store {
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    
    always {
      ent:store := ent:store.append([event:attrs])
    }   
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation

    always {
      ent:violations := ent:violations.append([event:attrs])
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset

    always {
      clear ent:store;
      clear ent:violations
    }
  }
}
