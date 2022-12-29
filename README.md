# Hyper Focus

Hyper Focus is a simple command line tool that watches for changes in the active window and prevents you from doing distracting things.

It allows you define what "distracting things" are for you using a schedule. For example, you might want to prevent yourself from using social media between 9am and 5pm. Or making certain google searches. Or using specific macOS applications.

In other words, if you are obsessive about personal productivity you can define what you want a productive day to look like and then use Hyper Focus to enforce it.

## Installation

```shell
brew install iloveitaly/tap/hyper-focus
```

You can then start the service via:

```shell
brew services start iloveitaly/tap/hyper-focus
```

When running via a brew service, the logs are located in `$(brew --prefix)/var/log/`.

Or, download a release build and run it manually

### Usage

```shell
hyper-focus --help

OVERVIEW: A daemon process which helps you focus on your work.

USAGE: hyper-focus [--version] [--configuration <configuration>]

OPTIONS:
  --version               Print out the version of the application.
  -c, --configuration <configuration>
                          Path to the configuration file
  -h, --help              Show help information.
```

## Why do this?

- https://marco.org/2015/10/30/automatic-social-discipline
- http://mikebian.co/tag/digital-minimalism/

## Features

- Fast, CLI-oriented tool
- Configuration in a simple JSON file ([here's an example](https://github.com/iloveitaly/dotfiles/blob/master/.config/focus/config.json))
- Very memory efficient, even over long periods of time
- No weird hangs or freezes like Focus app
- Sleep watching functionality so I don't need to rely on the abandonded sleepwatcher tool

### Sleepwatching

- Run a script on first wake of the day
- Run a script on each wake
- Run script as privileged in order to edit key system files like `/etc/hosts`

#### What is 'first wake'?

'First wake' means the first time the computer is woken from sleep for the current day.

Having a first wake script allows you to tie into something like [clean browsers](https://github.com/iloveitaly/clean-browser) and [todoist scheduler](https://github.com/iloveitaly/todoist-scheduler) to setup your workspace and todo list for the day.

### Scheduling

- Allow multiple blocking profiles that can be enabled at different times
- Ability to pause any active blocking for a period of time
- Ability to enable blocking for a period of time if no blocking is enabled

### Blocking

- Block macOS applications without quitting them. This is implemented by hiding them when you switch to them.
- "Block" websites by redirecting Chrome and Safari browsers to a page of your choosing when a banned URL is encountered.
- Block hosts
- Block specific URLs, ignoring anchors, and allowing a partial/subset match on query strings.

## Non-Features

- Executing scripts for other system states, like other sleep watcher tools. For instance, screen dim/wake or lid close/open.
- Kill/quit applications if they are open. This can be done via a wake script or schedule initialization script (`osascript -e 'quit app "App Name"'`).
- Notification when a new schedule is enabled. You could do this via a schedule initialization script.
- Native macOS application.

## HTTP API

Instead of UI, I've opted to a simple HTTP API that can be used to power a [Raycast](https://raycast.com/)-based UI.

- `/pause` pause the currently running schedule
- `/override` force a blocking profile to run for a period of time
- `/ping` is this thing on?
- `/configurations` array of names of all blocking profiles

## Development

- Run the binary manually `swift run`
- Copy local config `cp ./config.json ~/.config/focus/config.json`
- Generate a new release `git tag v0.1.3 && git push --tags origin HEAD`

## Tests

Haha! Nope.

This is a fun internal tool. Tests are boring, so I didn't write them.

## Inspiration

- https://github.com/qiuosier/SleepTight
- https://heyfocus.com
- https://github.com/ActivityWatch/aw-watcher-window
