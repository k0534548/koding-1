# Wrapper for pushing events to Rollbar
KD.logToExternal = (msg, args) ->
  return  unless KD.config.logToExternal and _rollbar
  return  if KD.isGuest()

  if args?
    args.msg = msg
    _rollbar.push args
  else
    _rollbar.push msg

# log ping times so we know if failure was due to user's slow
# internet or our internals timing out
KD.logToExternalWithTime = (name, options)->
  KD.troubleshoot (times)->
    KD.logToExternal {
      options
      msg      : "#{name} timed out"
      pings    : times
      protocol : KD.remote.mq.ws.protocol
    }

# set user info in rollbar for people tracking
KD.getSingleton('mainController').on "AccountChanged", (account) ->
  return  if KD.isGuest()
  return  unless KD.config.logToExternal and _rollbarParams

  user = KD.whoami?().profile
  _rollbarParams.person =
    id       : user.nickname or "unknown"
    name     : KD.utils.getFullnameFromAccount()
    username : user.nickname

# on logout reduce no. of errors logged to rollbar
# KD.getSingleton('mainController').on "AccountChanged", (account) ->
  # _rollbar.itemsPerMinute = 3  if KD.isGuest()
