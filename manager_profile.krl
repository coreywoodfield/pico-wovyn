ruleset manager_profile {
  meta {
    use module keys
    use module twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
  }

  global {
    number = "not my real number"
    from = "also not my real number"
  }

  rule violation {
    select when manager_profile threshold_violation
    twilio:send_sms(number, from, "Temperature over defined threshold")
  }
}
