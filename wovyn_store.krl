ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures
  }

  global {
    temperatures = function() {
      ent:store.defaultsTo([])
    }

    threshold_violations = function() {
      ent:violations.defaultsTo([])
    }

    inrange_temperatures = function() {
      ent:store.defaultsTo([]).filter(function(x){not (x >< ent:violations)})
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    always {
      ent:store := ent:store.defaultsTo([]).append([event:attrs])
    }   
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    always {
      ent:violations := ent:violations.defaultsTo([]).append([event:attrs])
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
