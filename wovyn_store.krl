ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures
  }

  global {
    temperatures = function() {
      ent:store
    }

    threshold_violations = function() {
      ent:violations
    }

    inrange_temperatures = function() {
      ent:store.filter(function(x){not (ent:violations >< x)})
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    always {
      ent:store := ent:store.append(event:attr("temperature").map(function(x){
        {"temperature": x{"temperatureF"}, "timestamp": event:attr("timestamp")}
      }))
    }   
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    always {
      ent:violations := ent:violations.append(event:attr("temperature").map(function(x){
        {"temperature": x{"temperatureF"}, "timestamp": event:attr("timestamp")}
      }))
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset
    always {
      ent:store := [];
      ent:violations := []
    }
  }

  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    if ent:store.isnull() && ent:violations.isnull() then noop();
    fired {
      ent:store := [];
      ent:violations := []
    }
  }
}
