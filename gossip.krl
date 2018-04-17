ruleset gossip {
  meta {
    use module io.picolabs.subscription alias subs
    shares getId, getTemps, getSeen, getOthers, __testing
    provides getId
  }

  global {
    __testing = {
      "queries": [
        { "name": "getTemps" },
        { "name": "getSeen" },
        { "name": "getId" },
        { "name": "getOthers" }
      ]
    }

    getId = function() {
      meta:picoId
    }

    getTemps = function() {
      ent:temps
    }

    getSeen = function() {
      ent:seen
    }

    getOthers = function() {
      ent:others
    }

    getPeer = function() {
      peers = subs:established("Tx_role", "node");
      needs = peers.filter(function(x) { needsInfo(ent:ids{x{"Tx"}}) });
      list = (needs.length() == 0) => peers | needs;
      length = list.length();
      sub = (length == 0) => null | ((length == 1) => list[0] | list[random:integer(length-1)]);
      sub.isnull() => null | {"eci": sub{"Tx"}, "id": ent:ids{sub{"Tx"}}}
    }

    getMessage = function(peer) {
      id = peer{"id"};
      messages = needsRumor(id) => [{"type": "rumor", "attrs": getRumor(id)}] | [];
      messages = messages.append(needsSeen(id) => {"type": "seen", "attrs": ent:seen} | []);
      m = (messages.length() == 0) => {"type": "seen", "attrs": ent:seen}
        | (messages.length() == 1) => messages[0]
        |                             messages[random:integer(messages.length()-1)];
      m
    }

    needsInfo = function(id) {
      needsRumor(id) || needsSeen(id)
    }

    needsRumor = function(id) {
      seen = ent:others{id};
      temps = ent:temps;
      temps.keys().any(function(id) {
        temps{id}.keys().any(function(sn) { (not (seen >< id)) || (sn > seen{id}) })
      })
    }

    getRumor = function(id) {
      seen = ent:others{id};
      temps = ent:temps;
      needed = temps.keys().any(function(id) {
        temps{id}.keys().any(function(sn) { (not (seen >< id)) || (sn > seen{id}) })
      });
      rid = needed.head();
      node_temps = temps{rid};
      hsn = (seen >< rid) => seen{rid} | -1;
      sn = node_temps.keys().filter(function(x) { x > hsn }).sort("numeric").head();
      node_temps{sn}.put("SensorID", meta:picoId)
    }

    needsSeen = function(id) {
      oseen = ent:others{id};
      seen = ent:seen;
      oseen.keys().any(function(id) {
        (not (seen >< id)) || (oseen{id} > seen{id})
      })
    }

    findSeen = function(id) {
      (ent:temps >< id) => findSeen2(ent:temps{id}, -1) | -1
    }

    findSeen2 = function(temps, num) {
      (temps >< (num + 1)) => findSeen2(temps, num + 1) | num
    }

    updateSeen = function(id, message) {
      mi_parts = message{"MessageID"}.split(re#:#);
      source_id = mi_parts[0];
      sn = mi_parts[1].as("Number");
      path = [id, source_id];
      (sn == ent:others{path} + 1) => ent:others.put(path, sn) | ent:others
    }

    addnewtemp = function(attrs) {
      old = (ent:temps >< meta:picoId) => ent:temps{meta:picoId} | {};
      mid = meta:picoId + ":" + ent:sequence_number.as("String");
      new = old.put(ent:sequence_number, {
        "MessageID": mid,
        "SensorID": meta:picoId,
        "Temperature": attrs{"temperature"},
        "Timestamp": attrs{"timestamp"}
      });
      ent:temps.put(meta:picoId, new)
    }
  }

  rule gossip_heartbeat {
    select when gossip heartbeat
    pre {
      peer = getPeer();
      message = peer.isnull() => null | getMessage(peer);
    }
    if (not message.isnull()) then event:send({
      "eci": peer{"eci"},
      "eid": "hi",
      "domain": "gossip",
      "type": message{"type"},
      "attrs": message{"attrs"}
    })
    fired {
      ent:others := (message{"type"} == "rumor") => updateSeen(peer{"id"}, message) | ent:others
    } finally {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:wait_seconds})
    }
  }

  rule new_temp {
    select when wovyn new_temperature_reading
    always {
      ent:seen := ent:seen.put(meta:picoId, ent:sequence_number);
      ent:temps := addnewtemp(event:attrs);
      ent:sequence_number := ent:sequence_number + 1
    }
  }

  rule gossip_rumor {
    select when gossip rumor
    pre {
      mi = event:attr("MessageID").split(re#:#);
      id = mi[0];
      sn = mi[1].as("Number")
    }
    if not (ent:temps{id} >< sn) then noop();
    fired {
      ent:temps := ent:temps.put(mi, event:attrs);
      ent:seen := ent:seen.put(id, findSeen(id))
    }
  }

  rule gossip_seen {
    select when gossip seen
    always {
      ent:seen := ent:seen.put(event:attr("id"), event:attr("seen"))
    }
  }

  rule new_peer {
    select when wrangler subscription_added
    foreach subs:established("name", event:attr("name")) setting (node)
    pre {
      eci = node{"Tx"}
    }
    event:send({
      "eci": eci,
      "edi": "eid",
      "domain": "gossip",
      "type": "register",
      "attrs": {
        "eci": node{"Rx"},
        "id": meta:picoId
      }
    })
  }

  rule register {
    select when gossip register
    pre {
      eci = event:attr("eci");
      id = event:attr("id")
    }
    always {
      ent:ids := ent:ids.put(eci, id);
      ent:others := (ent:others >< id) => ent:others | ent:others.put(id, {});
      ent:temps := (ent:temps >< id) => ent:temps | ent:temps.put(id, {})
    }
  }

  rule update_wait {
    select when gossip update
    pre {
      sn = event:attr("sequence_number")
    }
    if sn.isnull() then noop();
    notfired {
      ent:sequence_number := sn
    }
  }

  rule initialization {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      ent:sequence_number := 0;
      ent:wait_seconds := 20;
      ent:seen := {};
      ent:ids := {};
      ent:temps := {};
      ent:others := {};
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:wait_seconds})
    }
  }
}
