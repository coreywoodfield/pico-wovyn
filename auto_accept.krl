ruleset auto_accept {
  rule accept_subscription {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval" attributes event:attrs
    }
  }
}
