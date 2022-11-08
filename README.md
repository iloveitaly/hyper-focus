# Hyper Focus

WIP: still a todo list to work through before this is officially ready, but it's working locally for me.

## Features

* Fast, CLI-oriented tool
* Configuration in a simple JSON file
* Very memory efficient, even over long periods of time
* No weird hangs or freezes like Focus app
* Sleep watching functionality so I don't need to rely on the abandonded sleepwatcher tool

### Sleepwatching

* Run a script on first wake of the day
* Run a script on each wake
* Run script as privileged in order to edit key system files like `/etc/hosts`

#### What is 'first wake'?
'First wake' means the first time the computer is woken from sleep for the current day.

Having a first wake script allows you to tie into something like [clean browsers](https://github.com/iloveitaly/clean-browser) and [todoist scheduler](https://github.com/iloveitaly/todoist-scheduler) to setup your workspace and todo list for the day.


### Scheduling

* Allow multiple blocking profiles that can be enabled at different times
* Ability to pause any active blocking for a period of time
* Ability to enable blocking for a period of time if no blocking is enabled

### Blocking

* Block macOS applications without quitting them. This is implemented by hiding them when you switch to them.
* "Block" websites by redirecting Chrome and Safari browsers to a page of your choosing when a banned URL is encountered.
* Block hosts
* Block specific URLs, ignoring anchors, and allowing a partial/subset match on query strings.

## HTTP API

Instead of UI, I've opted to a simple HTTP API that can be used to power a [Raycast](https://raycast.com/)-based UI.

* `/pause` pause the currently running schedule
* `/override` force a blocking profile to run for a period of time
* `/ping` is this thing on?
* `/configurations` array of names of all blocking profiles

## Development

* `swift run`
* `cp ./config.json ~/.config/focus/config.json`

## Tests

Haha! Nope.

This is a fun internal tool. Tests are boring, so I didn't write them.

## Inspiration

* https://github.com/qiuosier/SleepTight
* https://heyfocus.com
* https://github.com/ActivityWatch/aw-watcher-window