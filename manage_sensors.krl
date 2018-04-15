ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subs
    shares sensors, temperatures, reports
  }

  global {
    threshold = 75

    sensors = function() {
      ent:sensors
    }

    temperatures = function() {
      sensors = subs:established("Tx_role", "sensor");
      temps = sensors.map(function(sensor) {
        wrangler:skyQuery(sensor{"Tx"}, "temperature_store", "temperatures")
      }).filter(function(x){not (x >< "error")});
      temps.reduce(function(a,b) {a.append(b)}, [])
    }

    reports = function() {
      reports = ent:reports.defaultsTo({}).values();
      length = reports.length();
      (length > 5) => reports.splice(length - 5, length) | reports
    }
  }

  rule request_temp_report {
    select when sensor request_report
    foreach subs:established("Tx_role", "sensor") setting (sensor)
    pre {
      eci = sensor{"Tx"}
      my_eci = sensor{"Rx"}
      rcn = ent:rcn.defaultsTo(0)
      reports = ent:reports.defaultsTo({})
    }
    event:send({
      "eci": eci,
      "eid": "whatever",
      "domain": "wovyn",
      "type": "report_requested",
      "attrs": {
        "eci": my_eci,
        "you": eci,
        "rcn": rcn
      }
    })
    always {
      ent:reports{rcn} := {"responders":0, "temperatures":[]};
      ent:rcn := rcn + 1 on final
    }
  }

  rule report_received {
    select when sensor report
    pre {
      rcn = event:attr("rcn")
      temps = event:attr("temps")
    }
    noop()
    always {
      ent:reports{[rcn, "responders"]} := ent:reports{[rcn, "responders"]} + 1;
      ent:reports{[rcn, "temperatures"]} := ent:reports{[rcn, "temperatures"]}.append(temps)
    }
  }

  rule create_sensor_pico {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then send_directive("Sensor already exists");
    notfired {
      raise wrangler event "child_creation" attributes {
          "name": name,
          "rids": ["temperature_store", "wovyn_base", "sensor_profile", "io.picolabs.subscription", "auto_accept", "gossip"]
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
      raise wrangler event "subscription" attributes {
        "name": name,
        "Rx_role": "manager",
        "Tx_role": "sensor",
        "channel_type": "subscription",
        "wellKnown_Tx": eci
      };
      ent:sensors := ent:sensors.put(event:attr("name"), eci)
    }
  }

  rule register_sensor {
    select when sensor register
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      host = event:attr("host")
      exists = ent:sensors >< name
    }
    if exists then send_directive("Sensor already exists");
    notfired {
      raise wrangler event "subscription" attributes {
        "name": name,
        "Rx_role": "manager",
        "Tx_role": "sensor",
        "channel_type": "subscription",
        "wellKnown_Tx": eci,
        "Tx_host": host
      };
      ent:sensors := ent:sensors.put(name, eci)
    }
  }

  rule unneeded_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    if exists then send_directive("deleting child");
    fired {
      raise wrangler event "child_deletion" attributes {"name": name};
      ent:sensors := ent:sensors.delete(name)
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
