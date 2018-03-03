ruleset manage_sensors {
  global {
    threshold = 75
  }

  rule create_sensor_pico {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then noop();
    fired {
      raise wrangler event "child_creation" attributes {
          "name": name,
          "rids": ["temperature_store", "wovyn_base", "sensor_profile"]
      }
    }
  }

  rule ready_sensor_pico {
    select when wrangler child_initialized
    pre {
      eci = event:attr("eci")
      name = event:attr("name")
    }
    event:send({
      "eci": eci,
      "eid": "is-this-important",
      "domain": "sensor",
      "type": "profile_updated",
      "attrs": {
        "name": name,
        "threshold": threshold,
        "number": "not my real number"
      }
    })
    always {
      ent:sensors := ent:sensors.put(event:attr("name"), eci)
    }
  }

  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    if ent:sensors.isnull() then noop();
    fired {
      ent:sensors := {}
    }
  }
}
