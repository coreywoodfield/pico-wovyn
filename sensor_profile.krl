ruleset sensor_profile {
  meta {
    provides query
    shares query
  }

  global {
    query = function() {
      {
        "threshold": ent:threshold,
        "number": ent:number,
        "location": ent:location,
        "name": ent:name
      }
    }
  }

  rule profile_update {
    select when sensor profile_updated
    always {
      ent:threshold := event:attr("threshold").defaultsTo(ent:threshold);
      ent:number := event:attr("number").defaultsTo(ent:number);
      ent:location := event:attr("location").defaultsTo(ent:location);
      ent:name := event:attr("name").defaultsTo(ent:name)
    }
  }

  rule initialization {
    select when wrangler ruleset_added where rids >< meta:rid
    if ent:threshold.isnull() &&
       ent:number.isnull() &&
       ent:location.isnull() &&
       ent:name.isnull() then noop();
    fired {
      ent:threshold := 75;
      ent:number := "not my real number";
      ent:location := "Provo";
      ent:name := "wovyn"
    }
  }
}
