# Imvu Scripting Documentation and Demos

Imvu Scripting is an alpha feature for our users which allows you to execute scripts in imvu rooms. For the alpha test, the context of these scripts is an individual Live Room, but we will release support for scripted products if everything goes to plan. Since you need a Live Room to run a script, this is a VIP-only alpha.

## Repository structure

We'll continue to add and extend documentation as the alpha continues. For now, you can find a primer here in the readme, and example scripts in the [scripts directory](scripts). In this readme file, you can find:

* [Getting Started](#getting-started), an illustrated guide for how to open the UI in web/desktop room deco.
* [Language and Framework](#language-and-framework), a basic overview.
* [Event Functions](#event-functions), detailed documentation for functions called when events happen in your room.
* [Basic imvu Methods](#basic-imvu-methods), detailed documentation for functions your script may call to provide output or request further input.
* [Resource Limits](#resource-limits), a brief explanation of the limits for your script sandbox.
* [Providing Feedback](#providing-feedback), a brief guide to how you can request information or help about the scripting alpha.

## Getting started

To use room scripting, eligible customers can find new UI elements in room deco mode on Web and Desktop. First, navigate to room deco mode and find the new `</>` scripting icon on the top-right hand corner.

![An image of the imvu room deco mode with the scripting icon highlighted by a red outline with a red arrow pointing to it](https://static-akm.imvu.com/imvufiles/scripting/step_one.png)

Once you click that icon, a new window should appear. The scripting ui is oriented around collapsible panels. The leftmost panel contains a list of all the scripts running in your room. At first, no scripts will be running. Click "Click here to start a new room script" to open up the room script editor.

![An image of the imvu room deco mode with the scripting UI open. The element which starts a new room script has been highlighted by a red outline with a red arrow pointing to it](https://static-akm.imvu.com/imvufiles/scripting/step_two.png)

This will add an entry for your currently empty room script. Click that entry to open the room script editor.

![An image of the imvu room deco mode with the scripting UI open. The element which selects a room script has been highlighted by a red outline with a red arrow pointing to it](https://static-akm.imvu.com/imvufiles/scripting/step_three.png)

The leftmost panel will immediately collapse and present you with three new panels. On the left is a list of **revisions**, which you can think of as files saved on the server containing your various scripts. In the center is a code editor, as well as buttons to save, start, and stop your script. On the right is the log output window, which will look empty at first.

![An image of the imvu room deco mode with the scripting UI open. The script is titled Draft and contains a single line of code, reading return {}](https://static-akm.imvu.com/imvufiles/scripting/step_four.png)

When you make changes and click Save, those changes are commited to the revision. When you click play, the script is started. When you click stop, the script is stopped. Clicking an X icon will unload a script to free up resources. As you use the scripting system, logs will appear on the right hand side.

## Language and Framework

For the alpha, the supported scripting language is lua, using the [Luau](https://github.com/luau-lang/luau) library for our runtime. Room scripts are single-file Lua scripts that must return an object. That object may contain functions that the scripting engine will call when certain events occur, but all of them are optional. That means the simplest working script is:

```
return {}
```

A (slightly) more practical example is:

```
local script = {}

function script.event_start()
    -- when the script is started, print to the room owner's private debug log
    imvu.debug("The script has started!")
end

function script.event_stop()
    -- when the script is stopped, print to the room owner's private debug log
    imvu.debug("The script has stopped!")
end

function script.begin_iteration(iteration, steady_clock)
end

function script.event_message_received(context, user, message)
    if message == "ping" then
        if context == "audience_whisper" or context == "scene_whisper" then
            -- when a room guest whispers 'ping' at the scripting persona, it whispers back
            imvu.whisper_audience_member(user.cid, "A whispered pong!")
        else
            -- when a room guest says 'ping' in public chat, it chats back
            imvu.message_audience("A public pong for " .. user.name)
        end
    end
end

function script.event_state_changed(context, user)
    if context == "audience_join" then
        -- when a user joins the audience, it sends a welcome message
        imvu.whisper_audience_member(user.cid, "Welcome to the chat, " .. user.name)
    end
end

function script.end_iteration()
end

-- when the script is loaded upon submission, print to the room owner's private debug log
imvu.debug("The script has loaded!")

return script
```

When a script is first loaded, it is executed and the returned value is stored for future callins. The scripting engine will call in with the following pattern:

* [**event_start**](#event_start), when the the script is started by room owner, or restarted by the system.
* Then, approximately every 50 milliseconds, we call:
    * [**event_begin_iteration**](#event_begin_iteration)
    * For every new event that's occurred in the room, we call the appropriate function:
        * [**event_message_received**](#event_message_received) for a message in the Scene or Audience.
        * [**event_state_changed**](#event_state_changed) for when a user leaves, joins, or moves in the Scene or Audience.
        * [**event_tip_received**](#event_tip_received) when a tip is received in the room.
        * If none of these events occurred, no functions will be called!
    * [**event_end_iteration**](#event_end_iteration)
* [**event_stop**](#event_stop), when the script is stopped by the room owner, or restarted by the system.

In the above example, the script will write to debug logs when the script is started, stopped, or loaded for the first time. It will respond if someone sends the message "ping" to the chat or in a whisper to the script's persona. It will also send a welcome message to everyone who joins the Audience.

There are other functions that the scripter may call at any time:

* [**imvu.debug**](#imvudebug) to send output to the room owner's scripting logs.
* [**imvu.message_audience**](#imvumessage_audience) to send a message on the Audience message mount.
* [**imvu.message_scene**](#imvumessage_scene) to send a message on the Scene message mount, which is useful for playing animations.
* [**imvu.whisper_audience_member**](#imvuwhisper_audience_member) to send a whisper to a member of the Audience.
* [**imvu.place_furniture**](#imvuplace_furniture) to place furniture in the scene.
* [**imvu.remove_furniture**](#imvuremove_furniture) to remove placed furniture from the scene.
* [**imvu.remove_all_furniture**](#imvuremove_all_furniture) to remove all furniture placed by the room script.
* [**imvu.remove_user_from_scene**](#imvuremove_user_from_scene) to kick a user's avatar out of the scene, turning them from a presenter to an Audience member.
* [**imvu.move_scene_member**](#imvumove_scene_member) to move a scene member to a selected seat in the room.
* [**imvu.send_room_invite**](#imvusend_room_invite) to send an invitation to another room.
* [**imvu.control_media**](#imvucontrol_media) to play, stop, pause, and otherwise control embedded youtube content.
* [**imvu.create_poll**](#imvucreate_poll) to create a new poll and registers a callback for when results are available.
* [**imvu.get_owner_cid**](#imvuget_owner_cid) to return the room owner's customer id.
* [**imvu.get_audience_members**](#imvuget_audience_members) to return a table of the current Audience members.
* [**imvu.get_scene_members**](#imvuget_scene_members) to return a table of the current Scene members, ie, presenters.

The following functions are currently in development and may not be accessible to all users:

* [**data.save**](#data.save) to save persistent data for your room script, with an arbitrary user-defined key.
* [**data.load**](#data.load) to load persistent data, using the same user-defined key.
* [**data.save_visitor**](#data.save_visitor) to save data keyed by a member of the audience.
* [**data.load_visitor**](#data.load_visitor) to load data keyed by a member of the audience.

## Event Functions

### event_start

This function is called when the script is started. This may be because the room decorator hit the 'play' button in the scripting UI, and it may be because the server restarted, and resumed the script after doing so. There are no parameters.

```
function script.event_start()
    imvu.debug('Script started!')
end
```

### event_stop

This function is called when the script is stopped. This may be because the room decorator hit the 'stop' button in the scripting UI, because the server is restarting and needs to stop your script to do so, or because you've submitted a new revision of the room script and the current one is stopping to get out of the way. There are no parameters.

```
function script.event_stop()
    imvu.debug('Script stopped!')
end
```

### event_begin_iteration

This function is called approximately 20 times a second by the scripting engine once the script has been started. It will precede the regular event functions, and the event_end_iteration function. It has two parameters

* **iteration** an integer counter of the iterations for the current run, reset when the script is started.
* **steady_clock** a floating point representing the number of seconds since the script started, precise to the millisecond.

```
function script.event_begin_iteration(iteration, steady_clock)
    imvu.debug('We reached iteration ' .. tostring(iteration) .. ' in ' .. tostring(steady_clock) .. ' seconds. If you actually output this into your logs, you will get 20 messages a second.')
end
```

### event_end_iteration

This function is called when an iteration completes. This is typically used to conclude per-iteration login in your script. It has no parameters.
```
function script.event_end_iteration()
    imvu.debug('The iteration ended. If you actually output this into your logs, you will get 20 messages a second')
end
```

### **event_message_received**

This function is called during the iteration event replay, when a message is received in the scene, in the audience, or as a whisper. It has the following parameters:

* **context** a string representing the context of the incoming message. As of now, it can have four possible values:
    * "audience" for a public message received in the audience.
    * "audience_whisper" for a private message received from an audience member.
    * "scene" for a public message received by a presenter in the scene.
    * "scene_whisper" for a private message received from a scene presenter.
* **user** is a table representing the user who sent the message. It has the following fields:
    * **user.cid** is the integer representation of the customer id, eg, `123456789`.
    * **user.name** is the string submitted by the customer as their display name, eg, `"Alice the Almighty"`.
    * **user.seat_number** is the nullable integer representation of the seat number, if the user is in the scene. If the user is not in the scene, it may be `nil`.
    * **user.seat_furni_id** is the nullable integer representation of the furniture id for where the user is seated, if the user is in the scene. If the user is not in the scene or not currently on a piece of furniture, it may be `nil`.
    * **user.seat_furni_pid** is the nullable integer representation of the furniture product id for where the user is seated, if the user is in the scene. If the user is not in the scene or not currently on a piece of furniture, it may be `nil`.
    * **user.seat_furni_label** is the nullable string representation of the furniture label for where the user is seated, if the user is in the scene. If the user is not in the scene, not currently on a piece of furniture, or on a piece of furniture which was not placed by the room script, it may be `nil`.
* **message** is the string submitted by the user, the message they actually sent.

```
function script.event_message_received(context, user, message)
    if message == "ping" then
        if context == "audience_whisper" or context == "scene_whisper" then
            imvu.whisper_audience_member(user.cid, "A whispered pong!")
        else
            imvu.message_audience("A public pong for " .. user.name)
        end
    end
end
```

### **event_state_changed**

This function is called during the iteration event replay, when the state tracked by the room changes. Practically speaking, this happens when a user joins, leaves, or moves in a scene. It has the following parameters:

* **context** a string representing the context of the incoming message. As of now, it can have four possible values:
    * "audience_join" for a user joining the audience.
    * "audience_leave" for a user leaving the audience.
    * "scene_join" for a user joining the scene, ie, becoming a presenter.
    * "scene_leave" for a user leaving the scene, ie, losing presenter status and rejoining the audience as an unseen member.
    * "scene_move" for a user moving their avatar around the scene.
* **user** is a table representing the user who sent the message. It has the following fields:
    * **user.cid** is the integer representation of the customer id, eg, `123456789`.
    * **user.name** is the string submitted by the customer as their display name, eg, `"Alice the Almighty"`.
    * **user.seat_number** is the nullable integer representation of the seat number, if the user is in the scene. If the user is not in the scene, it may be `nil`.
    * **user.seat_furni_id** is the nullable integer representation of the furniture id for where the user is seated, if the user is in the scene. If the user is not in the scene or not currently on a piece of furniture, it may be `nil`.
    * **user.seat_furni_pid** is the nullable integer representation of the furniture product id for where the user is seated, if the user is in the scene. If the user is not in the scene or not currently on a piece of furniture, it may be `nil`.
    * **user.seat_furni_label** is the nullable string representation of the furniture label for where the user is seated, if the user is in the scene. If the user is not in the scene, not currently on a piece of furniture, or on a piece of furniture which was not placed by the room script, it may be `nil`.
    * **user.outfit** is an array-style table containing the products in the user's outfit, eg, `[80, 10000, 20000]`. This may be used to discriminate script behavior depending on whether the avatar is wearing a certain product.
* **message** is the string submitted by the user, the message they actually sent, eg, `"Hello, world!"`

```
function script.event_message_received(context, user, message)
    if message == "ping" then
        if context == "audience_whisper" or context == "scene_whisper" then
            imvu.whisper_audience_member(user.cid, "A whispered pong!")
        else
            imvu.message_audience("A public pong for " .. user.name)
        end
    end
end
```

### **event_tip_received**

This function is called during the iteration event replay, when a tip is sent in the room. It has the following parameters:

* **sender** a table representing the user who sent the tip. It has the following fields:
    * **sender.cid** is the integer representation of customer id, eg, `567891234`.
    * **sender.name** is the string submitted by the customer as their display name, eg, `"Bob the Bodacious"`.
* **recipient** a table representing the user who received the tip. It has the following fields:
    * **recipient.cid** is the integer representation of the customer id, eg, `987654321`.
    * **recipient.name** is the string submitted by the customer as their display name, eg, `"Charlie the Courageous"`.
* **credits_sent** the integer representing the credits sent by the tipper, before any transaction fees.
* **is_private** the boolean representing whether or not the tip was private.

```
function script.event_tip_received(sender, recipient, credits_sent, is_private)
    if recipient.cid == imvu.get_owner_cid() then
        if is_private then
            imvu.whisper_audience_member(recipient.cid, "Thanks for the tip, " .. recipient.name)
        else
            imvu.send_audience_message("Hey, everyone, " .. recipient.name .. " is now my favorite person.")
        end
    end
end
```

## Basic imvu methods

These methods are available to all scripters. They provide basic interactivity with the room.

### **imvu.debug**

This sends output to the room owner's scripting logs. It has a single parameter:

* **content** may be either a string or an `error`, which is defined as a table with `type` and `message` fields. The compatibility with the `error` type is for ease of use when calling methods like [create_poll](#imvucreate_poll), which provide an error_callback parameter.

```
local function process_results(results)
    local output = ''
    for i, v in ipairs(results.tallies) do
        if #output > 0 then
            output = output .. ' and '
        end
        output = output .. v.content ' got ' .. v.tally .. ' votes '
    end
    imvu.debug(output)                              # this will print poll results to a log, if the poll completes successfully
end

imvu.debug('About to create a poll!')               # this will print a simple message to the log
imvu.create_poll(poll, process_results, imvu.debug) # this will print errors directly to the log, if something goes wrong, because imvu.debug is the third parameter.
```

### **imvu.message_audience**

This function sends a message to the audience. It has a single parameter, the message to be sent.

* **message** is the string to send to the audience. The normal length and content limits for an outgoing message still apply. Additionally, there are top-level limits imposed against the script persona in any given room.

```
imvu.message_audience("There is no <b>html</b> or [b]bbcode[/b] or **markdown** formatting available in imvu chats right now. Your messages will be sent as utf8 plaintext, which should allow 𝒖𝒏𝒊𝒄𝒐𝒅𝒆 𝒇𝒐𝒓𝒎𝒂𝒕𝒕𝒊𝒏𝒈. We have resigned ourselves to your emoji-based crimes 🙃")
```

### **imvu.message_scene**

This function sends a message on the scene message mount. It has a single parameter, the message to be sent.

* **message** is the string to send to the scene. Generally, this is useful for playing animations on furniture. If you want to cue the `flip` animation on a piece of furniture, try:

```
imvu.message_scene("*imvu:trigger flip")
```

### **imvu.whisper_audience_member**

This function sends a private message to a given audience member. It has two parameters.

* **cid** is the integer customer id of the recipient of the message. It must be a current member of the audience, and the attempt will fail if the user leaves the room before the whisper can be dispatched.
* **message** is the message to be sent.

```
imvu.whisper_audience_member(user.cid, "Hello, " .. user.name)
```

### **imvu.place_furniture**

This function places furniture in the scene. The room owner must also own the furniture product, or the placement will fail. It has a single argument, the `furniture` structure requested.

* **furniture_request** A table containing the following fields
    * **furniture_request.label** a string (which must start with an alphabetic english letter, A-Z or a-z) which defines the furniture entry. When you make repeated requests to place furniture with the same label, that furniture item will be moved, rather than repeated.
    * **furniture_request.pid** an integer representing the product id of the furniture to be placed. It must be owned by the room owner.
    * **furniture_request.node** the node where the furniture should be anchored, eg, "furniture.Floor.178"
    * **furniture_request.x** (optional, default 0) a floating point number representing the x-axis offset for where the furniture should be placed, eg, how far it should move side to side.
    * **furniture_request.y**  (optional, default 0) a floating point number representing the y-axis offset for where the furniture should be placed, eg, how far it should move up and down.
    * **furniture_request.z** (optional, default 0)  a floating point number representing the z-axis offset for where the furniture should be placed, eg, how far it should move back and forth.
    * **furniture_request.yaw** (optional, default 0) a floating point number representing the rotation of the furniture, how far it should turn side to side.
    * **furniture_request.pitch** (optional, default 0) a floating point number representing the rotation of the furniture, how far it should tilt up or down.
    * **furniture_request.roll** (optional, default 0) a floating point number representing the rotation of the furniture, how far it should roll side to side.
    * **furniture_request.scale** (optional, default 1.0) a floating point number representing the relative scale of the furniture, minimum 0.01
    * **furniture_request.freeplay_attrs** (optional, default nil) a table representing how audience members are allowed to move the furniture while in the room.
        * **furniture_request.freeplay_attrs.enabled** (optional, default false) a boolean value for whether freeplay is enabled. When it is enabled, users in the room who use supported clients can move the furniture.
        * **furniture_request.freeplay_attrs.all_nodes** (optional, default false) a boolean value for whether users can change the node anchoring the furniture in free-play. If it is set to true, they may move it to any node. If you wish for the target nodes to be limited to specific furniture items, use the `fids` field, below.
        * **furniture_request.freeplay_attrs.x** (optional, default false) a boolean value for whether users can change the x translation of the furniture.
        * **furniture_request.freeplay_attrs.y** (optional, default false) a boolean value for whether users can change the y translation of the furniture.
        * **furniture_request.freeplay_attrs.z** (optional, default false) a boolean value for whether users can change the z translation of the furniture.
        * **furniture_request.freeplay_attrs.yaw** (optional, default false) a boolean value for whether users can change the yaw rotation of the furniture.
        * **furniture_request.freeplay_attrs.pitch** (optional, default false) a boolean value for whether users can change the pitch rotation of the furniture.
        * **furniture_request.freeplay_attrs.roll** (optional, default false) a boolean value for whether users can change the roll rotation of the furniture.
        * **furniture_request.freeplay_attrs.scale** (optional, default false) a boolean value for whether users can change the scale of the furniture.
        * **furniture_request.freeplay_attrs.fids** (optional, default nil) an optional array-style table of strings representing the valid furniture IDs where this movable furniture may be anchored, eg: ["123", "8235", "32"]. In the current alpha, this field is incompatible with furniture labels, and is generally used with furniture manually placed in room deco mode. As an example, you can place a chessboard and use scripting to controll chess pieces, which user may then move onto nodes limited to that board.

```
-- this command will place a single instance of pid 123456 on furniture.Floor.01
local furn = { label = "one", pid = 123456, node = "furniture.Floor.01" }
imvu.place_furniture(furn)

-- this command will move that furniture a little to the left
furn.x = -3
imvu.place_furniture(furn)

-- this command will place a second piece of furniture, because we've changed the label.
furn.label = "two"
furn.x = 5
imvu.place_furniture(furn)
```

### **imvu.remove_furniture**

This function removes placed furniture from the scene. It must be furniture placed by the room script. It has a single parameter.

* **label** the label of the furniture to remove.

```
imvu.remove_furniture("one")
```

### **imvu.remove_all_furniture**

Temporarily Disabled! This function removes all furniture placed by the script, and should leave other furniture untouched. It has no parameters.

```
imvu.remove_all_furniture()
```

### **imvu.remove_user_from_scene**

This function kicks a user's avatar out of the scene, turning them from a presenter to an Audience member. It has a single argument.

* **cid** the integer representation of the customer id to remove from the scene. They will not be completely removed from the room, merely turned into an audience member without an avatar in the scene.

```
imvu.remove_user_from_scene(user.cid)
```

### **imvu.move_scene_member**

This function moves a presenter's avatar to a new node. It has two arguments.

* **cid** the integer representation of the customer id to move.
* **seats** an array-style table listing the seat nodes targeted as a destination. The seats listed will be attempted in order. If the first one is full, the second one will be attempted, and if the second one is full, the third one will be attempted, and so on. Every seat entry is itself a table with two fields:
    **seats[1].seat_number** is the integer-formatted seat number to target.
    **seats[1].seat_furniture** (optional, default nil) is for the furniture to target. If it is a valid furniture label, it will attempt to target furniture placed by the script according to label. If it is an integer furniture id, it will attempt to target that furniture id directly, allowing you to place users on furniture placed in room-deco mode.

```
seat_one = { seat_number = 4 }                              # placement on room seat 4
seat_two = { seat_furniture = 123, seat_number = 1 }        # placement on furniture id 123's seat 1
seat_three = { seat_furniture = "hello", seat_number = 3}   # placement on script-managed furniture with label "hello"
imvu.move_scene_member(user.cid, { seat_one, seat_two, seat_three })
```

### **imvu.send_room_invite**

This function sends a room invitation to a user presently in your scripted room. You can use this to coordinate movement between rooms, similar to the old portal experiment. Should you send an invite to one of your rooms which is invite-only or which has a guest list, the targeted user will be allowed to join that room and/or added to the guest list.

This function has two mandatory parameters and one optional parameter.

* **room_id** which is a variably typed argument. If it is an integer, it will send the invite for the appropriate room owned by the current room owner. If it is a string with a value in the format of `CID-ROOMID`, it will send an invite for that room, if possible. For example, a value of `12` will invite a user to your room 12. A value of `1234567-89` will send an invite for 
* **cid** which is the integer representation of the customer id to invite.
* **portal_mode** (optional, default false) a boolean representing whether or not to send the invite in portal mode. A portal mode invite will automatically remove the user from this scripted room when they accept the dispatched room invite, simulating physical movement from one room to another.

```
imvu.send_room_invite(30, user.cid)                 # send a normal invite to the room owner's room #30
imvu.send_room_invite("1234567-80", user.cid)       # send a normal invite to CID 1234567's room #80
imvu.send_room_invite(20, user.cid, true)           # send a portal mode invite to the room owner's room #20
```

### **imvu.control_media**

This function controls embedded media in the room. Right now, it is limited to youtube videos displayed on compatible furniture products. It has two arguments.

* **command** the command to execute against the embedded media. Valid values are:
    * "play_media" to start it.
    * "stop_media" to stop it.
    * "pause_media" to pause it.
    * "set_title" to attempt to change the title in exclusion to other parameters.
    * "set_volume" to attempt to change the audio volume in exclusion to other parameters.
* **media_params** a table representing where the embedded media should be oriented. It has the following fields:
    * **media_params.label** the furniture label to target with the embedded video
    * **media_params.target_name** the material on the furniture product to target with the embedded video
    * **media_params.provider** (optional, default "youtube") the media type to embed. Right now the only valid value is "youtube"
    * **media_params.format** (optional, default "recording") the media format to embed. Right now the only valid value is "recording"
    * **media_params.media_title** (optional, default "Untitled") the title of the media to present to users in the room.
    * **media_params.media_url** (optional, default "") the url to play. An example value is `"https://www.youtube.com/watch?v=dQw4w9WgXcQ"`. Imvu does not control the youtube api's limitation for what videos can play on what clients, on what devices, or in what markets. The previously provided example will almost certainly not play for most of your guests, due to licensing and monetization policies. Experimentation is necessary, even if you attempt to stream your own uploaded content.
    * **media_params.media_timestamp** (optional, default 0) the number of seconds to skip ahead when starting the content.
    * **media_params.media_volume** (optional, default 100) a percentage-based configuration for the audio volume of the content.
    * **media_params.media_playback_speed** (optional, default 1) a multiplier-based configuration for the playback speed of the content.

The normal limitations for streaming media apply. You can only stream in one room, and imvu will automatically stop the stream if the room owner leaves the room.

```
-- a valid pid for playing youtube content in a Live Room
local screen = { pid = 52977230, label="screen", node="furniture.Floor.300", x = -0.11, z = -5.36, yaw = 1.7 }
local media_params = { media_title = "Jazz Cat", media_url = "https://www.youtube.com/watch?v=zWLAbNHn5Ho", media_timestamp = 0, label = "screen", target_name = "material1" }
imvu.place_furniture(screen)

-- note that in this example, the following call may fail, because the furniture placement may not occur in time for the play command to function as expected. In practice, you will want to call play_media from furniture you placed at startup or in a previous iteration.
imvu.control_media("play_media", media_params)

media_params.media_volume = 50
imvu.control_media("set_volume", media_params)
```

### **imvu.create_poll**

This method attempts to create a poll for your guests, and registers a callback function for the results. It has two required arguments and one optional argument.

* **poll_params** a table representing the poll requested.
    * **poll_params.type** (optional, default "custom") specifying the type of poll, with two valid values: "custom" or "presenter"
        * "custom" allows guests to vote on arbitrary strings. This can, for example, let them vote for Cake or Pie.
        * "presenter" allows guests to vote on current presenters at the time the poll is created. This can, for example, let them vote for the hottest avatar in a room.
    * **poll_params.content** (optional, default "") which is the topic of the poll. Examples include, "Vote for your favorite dessert" or "Vote for who I kick from the room next"
    * **poll_params.duration** (optional, default 60, minimum 10, maximum 1800) is the duration of the poll in seconds.
    * **poll_params.options** is the table of options to present to guests. It is an array-style list of variable value types:
        * For custom polls, the values must be strings, eg, { "cats", "dogs" }
        * For presenter polls, the values must be either integer cid values or user tables containing the field `cid`, eg, { 123456, { cid = 56789, name = "Bob"}, 32314 }. These users must be presenters in the room at the time the poll starts.
* **success_callback** a function that will be called when the poll is complete. The function will be offered a single parameter.
    * **results** is the parameter provided to the callback. It is a table with the following fields.
        * **results.tallies** contain the options provided for the poll, in order of most votes to least.
            * **results.tallies[1].tally** is the total number of users who voted for it. This field is universal across poll types.
            * For custom polls only:
                * **results.tallies[1].content** is the string content for the option.
            * For presenter polls only:
                * **results.tallies[1].user.cid** is the integer-typed customer id.
                * **results.tallies[1].user.name** is the display name for the presenter.
        * [Currently Disabled[<sup>1</sup>](#footnotes)] **results.votes** lists who voted for what, in an array-style table of results.
            * **results.votes[1].voters** is an array-style table of the voters who selected the associated option.
                * **results.votes[1].voters[1].cid** is the integer typed customer id of the voter.
                * **results.votes[1].voters[1].name** is the display name of the voter.
            * For custom polls only:
                * **results.votes[1].option.content** is the string content for the option.
            * For presenter polls only:
                * **results.votes[1].option.cid** is the integer typed customer id of the option, eg, who they voted for.
                * **results.votes[1].option.name** is the display name of the option, eg, who they voted for.
* **failure_callback** a function that will be called should something go wrong with the poll.

```
-- a simple example of a custom poll
local custom_params = { type = 'custom', content = 'Best Dessert?', duration = 60, { "cake", "pie" }}
imvu.create_poll(custom_params,
-- the second parameter is a success callback
-- you don't have to do anything with the results, really, but you must provide a function to accept them.
function(results)
    imvu.message_audience('Thanks for voting, everyone!')
end,
-- the first parameter is an error callback
-- it is optional and can be omitted. if you provide imvu.debug as the error callback, it will print errors to the log
imvu.debug)

-- a more complicated example of a presenter poll.
-- first, find the people in the scene for a 1v1 dance-off
local dancers = imvu.get_scene_membrers()
-- create a poll for a dance-off
local poll_params = {
        type = 'presenter',
        content = 'Vote for the best Dancer!',
        duration = 60,
        options = dancers
    }
imvu.create_poll(poll_params, 
-- the second parameter is a success callback
function(results)
    if #results.tallies > 0 then
        -- if we have any votes at all, the winner will be first in the tallies array
        local winner = results.tallies[1]
        local loser = {}
        if #results.tallies > 1 then
            loser = results.tallies[2]
        elseif winner.user.cid == dancers[1].cid then
            loser = { user = dancers[2], tally = 0 }
        else
            loser = { user = dancers[1], tally = 0 }
        end
        -- print some debug information for our private logs
        imvu.debug("winner: " .. winner.user.cid .. " votes: " .. winner.tally)
        imvu.debug("loser: " .. loser.user.cid .. " votes: " .. loser.tally)
        -- it's possible we have a tie, so check to make sure the winner has more votes than the loser
        if winner.tally > loser.tally then
            -- if so, build output to print to the audience and remove the loser from the scene
            local output = "The winner is " .. winner.user.name
            output = output .. " with " .. winner.tally
            output = output .. " votes!"
            output = output .. ". Congratulations, and feel free to stick around for a fresh challenger. Sorry, " .. loser.user.name .. ", you lose!"
            imvu.message_audience(output)
            imvu.debug("Attempting to remove user from scene: " .. loser.user.cid)
            imvu.remove_user_from_scene(loser.user.cid)
        else
            -- if it is a tie, kick them both from the scene!
            imvu.message_audience("It's a tie! Congratulations to our dual dance champions. Now, let someone else have a try!")
            imvu.remove_user_from_scene(winner.user.cid)
            imvu.remove_user_from_scene(loser.user.cid)
        end
    else
        -- if nobody voted, complain and resort to violence
        imvu.message_audience("Nobody voted?! Everyone loses, get outta here you two!")
        imvu.remove_user_from_scene(dancers[1].cid)
        imvu.remove_user_from_scene(dancers[2].cid)
    end
end,
-- the third parameter is a failure callback
function(error)
    -- when something goes wrong, print it to our private logs and apologize
    imvu.debug(error)
    imvu.message_audience("Uh oh... the poll failed! Sorry about that folks, let's try again.")
end)
```

### **imvu.get_owner_cid**

This function returns the owner's customer id as an integer.

### **imvu.get_audience_members**

This function returns an array-style table that contains the users in the audience. Each entry is a table with the following fields:
* **cid** which returns the integer customer id for the audience member.
* **name** which returns the display name for the audience member.

### **imvu.get_scene_members**

This function returns an array-style table that contains the users in the scene. Each entry is a table with the following fields:

* **cid** which returns the integer customer id for the scene presenter.
* **name** which returns the display name for the scene presenter.
* **seat_number** which returns the seat number for the scene presenter.
* **seat_furni_id** is the nullable integer representation of the furniture id for where the user is seated. If the user is not currently on a piece of furniture, it may be `nil`.
* **seat_furni_pid** is the nullable integer representation of the furniture product id for where the user is not currently on a piece of furniture, it may be `nil`.
* **seat_furni_label** is the nullable string representation of the furniture label for where the user is seated. If the user is not on a piece of furniture which was not placed by the room script, it may be `nil`.
* **outfit** is an array-style table containing the products in the user's outfit, eg, `[80, 10000, 20000]`. This may be used to discriminate script behavior depending on whether the avatar is wearing a certain product.

## Resource Limits

Currently, every individual room is limited to approximately 10 megabytes of memory in its lua sandbox, including around 400 kilobytes of overhead. Every individual user is limited to a single CPU core across all their rooms, and individual iterations should not exceed 50ms of lua processing time per iteration.

Outgoing messages, room invites, and other output to your visitors are also rate-limited, to help prevent obstructive amounts of spam. No matter what you attempt to do with your script, you should only be able to target current members of the room. This means a user can always escape unwanted behavior by simply leaving your room.

## Providing Feedback

You may file an issue against this repository, if you have a github account, or use the creator feedback forums where the experiment was first announced. We're eager to hear from our alpha testers about every aspect of the experiment.

## Footnotes

1. Voter output is currently disabled for alpha testers, as we discuss the user safety implications. The existing polling feature doesn't allow the host to see who voted for what, so there's an implicit anonymity to it. We may not want to violate that assumption without clearly communicating it to our users.