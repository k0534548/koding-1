###
  todo:
    - fix password confirmation bug on kodingen username case
###


class RegisterInlineForm extends LoginViewInlineForm

  constructor:->

    super
    @firstName = new LoginInputView
      cssClass        : "half-size"
      inputOptions    :
        name          : "firstName"
        placeholder   : "Your first name"
        validate      :
          event       : "blur"
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your first name."

    @lastName = new LoginInputView
      cssClass        : "half-size"
      inputOptions    :
        name          : "lastName"
        placeholder   : "Your last name"
        validate      :
          event       : "blur"
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your last name."

    @email = new LoginInputViewWithLoader
      inputOptions    :
        name          : "email"
        placeholder   : "Your email address"
        validate      :
          event       : "blur"
          rules       :
            required  : yes
            email     : yes
            available : (input, event)=>
              return if event?.which is 9
              input.setValidationResult "available", null
              email = input.inputGetValue()
              if input.valid
                @email.loader.show()
                bongo.api.JUser.emailAvailable email, (err, response)=>
                  @email.loader.hide()
                  if err then warn err
                  else
                    if response
                      input.setValidationResult "available", null
                    else
                      input.setValidationResult "available", "Sorry, \"#{email}\" is already in use!"
              return
          messages    :
            required  : "Please enter your email address."
            email     : "That doesn't seem like a valid email address."
        blur          : (input, event)=>
          @utils.nextTick =>
            @userAvatarFeedback input
    
    @avatar = new AvatarStaticView
      size        :
        width     : 20
        height    : 20
    , profile     : 
        hash      : md5.digest "there is no such email"
        firstName : "New koding user"
    @avatar.hide()

    @username = new LoginInputViewWithLoader
      inputOptions       :
        name             : "username"
        forceCase        : "lowercase"
        placeholder      : "Desired username"
        validate         :
          rules          :
            required     : yes
            rangeLength  : [4,25]
            regExp       : /^[a-z\d]+([-][a-z\d]+)*$/i
            usernameCheck: (input, event)=> @usernameCheck input, event
            finalCheck   : (input, event)=> @usernameCheck input, event
          messages       :
            required     : "Please enter a username."
            regExp       : "For username only lowercase letters and numbers are allowed!"
            rangeLength  : "Username should be minimum 4 maximum 25 chars!"
          events         :
            required     : "blur"
            rangeLength  : "keyup"
            regExp       : "keyup"
            usernameCheck: "keyup"
            finalCheck   : "blur"
        iconOptions      :
          tooltip        :
            placement    : "right"
            offset       : 2
            title        : """
                            Only lowercase letters and numbers are allowed, 
                            max 25 characters. Also keep in mind that the username you select will 
                            be a part of your kodingen domain, and can't be changed later. 
                            i.e. http://username.kodingen.com <h1></h1>
                           """

    @password = new LoginInputView
      inputOptions    :
        name          : "password"
        type          : "password"
        placeholder   : "Create a password"
        validate      :
          event       : "blur"
          rules       :
            minLength : 8
          messages    :
            minLength : "Password is required and should at least be 8 characters."

    @passwordConfirm = new LoginInputView
      cssClass        : "password-confirm"
      inputOptions    :
        name          : "passwordConfirm"
        type          : "password"
        placeholder   : "Confirm your password"
        validate      :
          event       : "blur"
          rules       :
            required  : yes
            match     : @password.input
          messages    :
            match     : "Password confirmation doesn't match!"
            match     : "Password confirmation is required!"

    @button = new KDButtonView
      title         : "REGISTER"
      type          : 'submit'
      style         : "koding-orange"
      loader        :
        color       : "#ffffff"
        diameter    : 21
    
    @invitationCode = new LoginInputView
      cssClass        : "half-size"
      inputOptions    :
        name          : "inviteCode"
        forceCase     : "lowercase"
        placeholder   : "your code..."
        # defaultValue  : "futureinsights"
        validate      :
          event       : "blur"
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your invitation code."


  usernameCheckTimer = null

  usernameCheck:(input, event)->

    return if event?.which is 9

    clearTimeout usernameCheckTimer
    input.setValidationResult "usernameCheck", null
    name = input.inputGetValue()

    if input.valid
      usernameCheckTimer = setTimeout =>
        @username.loader.show()
        bongo.api.JUser.usernameAvailable name, (err, response)=>
          @username.loader.hide()
          {kodingUser, kodingenUser} = response
          if err
            if response?.kodingUser
              input.setValidationResult "usernameCheck", "Sorry, \"#{name}\" is already taken!"
              @hideOldUserFeedback()
          else
            if kodingenUser
              @showOldUserFeedback()
            else if kodingUser
              input.setValidationResult "usernameCheck", "Sorry, \"#{name}\" is already taken!"
              @hideOldUserFeedback()
            else
              @hideOldUserFeedback()
              input.setValidationResult "usernameCheck", null
      ,800
    else
      @hideOldUserFeedback()
    return

  showOldUserFeedback:->
    
    @parent.setClass "taller"
    @username.setClass "kodingen"
    @passwordConfirm.setHeight 0
    @$('p.kodingen-user-notification b').text "#{@username.input.inputGetValue()}"
    @$('p.kodingen-user-notification').height 54

  hideOldUserFeedback:->
    
    @parent.unsetClass "taller"
    @username.unsetClass "kodingen"
    @$('p.kodingen-user-notification').height 0
    @passwordConfirm.setHeight 32

  userAvatarFeedback:(input)->

    if input.valid
      @avatar.setData 
        profile     : 
          hash      : md5.digest input.inputGetValue()
          firstName : "New koding user"
      @avatar.render()
      @showUserAvatar()
    else
      @hideUserAvatar()

  showUserAvatar:-> @avatar.show()

  hideUserAvatar:-> @avatar.hide()

  viewAppended:()->

    super
    KD.getSingleton('mainController').registerListener
      KDEventTypes  : 'InvitationReceived'
      listener      : @
      callback      : (pubInst, invite)=>
        @$('.invitation-field').addClass('hidden')
        @$('.invited-by').removeClass('hidden')
        {origin} = invite
        @invitationCode.input.inputSetValue invite.code
        @email.input.inputSetValue invite.inviteeEmail
        if origin instanceof bongo.api.JAccount
          @addSubView new AvatarStaticView({size: width : 30, height : 30}, origin), '.invited-by .wrapper'
          @addSubView new ProfileTextView({}, origin), '.invited-by .wrapper'
        else
          @$('.invited-by').addClass('hidden')

  pistachio:->

    """
    <div>{{> @firstName}}{{> @lastName}}</div>
    <div>{{> @email}}{{> @avatar}}</div>
    <div>{{> @username}}</div>
    <div>{{> @password}}</div>
    <div>
      {{> @passwordConfirm}}
      <p class='kodingen-user-notification'>
        <b>This</b> is a reserved Kodingen username, if you own this 
        account please type your Kodingen password above to unlock your old
        username for the new Koding.
      </p>
    </div>
    <div class='invitation-field invited-by hidden'>
      <span class='icon'></span>
      Invited by:
      <span class='wrapper'></span>
    </div>
    <div class='invitation-field clearfix'>
      <span class='icon'></span>
      Invitation code:
      {{> @invitationCode}}
    </div>
    <div>{{> @button}}</div>
    """
