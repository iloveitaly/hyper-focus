# Hyper Focus

Hyper Focus is a command line tool that watches what you are doing on your computer and prevents you from doing distracting things.

It allows you define what "distracting things" are for you. For example, you might want to prevent yourself from using social media between 9am and 5pm. Or making certain google searches. Or using specific macOS applications. You can define what activities are distracting on a schedule.

In other words, if you are obsessive about personal productivity you can define what you want a productive day to look like and then use Hyper Focus to enforce it.

## Installation

```shell
brew install iloveitaly/tap/hyper-focus
```

You can then start the service as a daemon:

```shell
brew services start iloveitaly/tap/hyper-focus
```

Or run it directly:

```shell
hyper-focus

# you may want to run as root if your scripts are modifying system files, like /etc/hosts
sudo hyper-focus --configuration ~/.config/focus/config.json
```

When running via a brew service, the logs are located in `$(brew --prefix)/var/log/`. You can tail the logs:

```shell
tail -f $(brew --prefix)/var/log/hyper_focus.log
```

Or, download a release build and run it manually.

You'll need to grant accessibility permissions to the binary, which you can find via `brew which hyper-focus`. If scripts you have defined require root access, you'll also need to grant full disk access to the binary as well.

### Running a Brew Service as Root

You may want to run Hyper Focus as root. For instance, [if you are modifying the `/etc/hosts` file on wake](https://github.com/iloveitaly/dotfiles/blob/7209676edb8417436bf9e56f1137a0b23bfadf76/.config/focus/wake.sh#L23),
you need to run Hyper Focus as root.

Here's how to do it:

```shell
sudo brew services start iloveitaly/tap/hyper-focus
```

<!--
Couple notes:

- Notification language when starting the process via brew is confusing

- Start the non-root service using `brew services start hyper-focus`
- Copy the existing plist `cat ~/Library/LaunchAgents/homebrew.mxcl.hyper-focus.plist | pbcopy`
- Stop the non-root service `brew services stop hyper-focus`
- Create the root service `sudo sh -c "pbpaste > /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist"`
- Start the process as root `sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist`

Here's a script:

```shell
brew services start hyper-focus
cat ~/Library/LaunchAgents/homebrew.mxcl.hyper-focus.plist | pbcopy
brew services stop hyper-focus

sudo sh -c "pbpaste > /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist"
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist
```

To unload

```shell
sudo launchctl unload /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist
```
-->

<!--
(TODO: still need to ensure that this works on restart, since it seems to do the same operation as `sudo brew services ...`)
(TODO: note about permissions, needing to remove logfiles, when switching between non-root and root)
TODO add something about the full disk permissions and accessibility permissions
(TODO I think we can remove this when https://github.com/Homebrew/homebrew-services/issues/554 is resolved)
-->

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
- [UI via Raycast](https://www.raycast.com/iloveitaly/hyper-focus)
- Configuration in a simple JSON file ([here's an example](https://github.com/iloveitaly/dotfiles/blob/master/.config/focus/config.json))
- Very memory efficient, even over long periods of time
- No weird hangs or freezes (Focus app had this issue)
- Run scripts on sleep events (you don't need to rely on the abandoned sleepwatcher tool)
- Treat long periods of no activity as sleep, and execute relevant scripts
- Ability to run as root (if you need to modify system files, like `/etc/hosts`)

### Sleepwatching

- Run a script on first wake of the day
- Run a script on each wake
- Run script as privileged in order to edit key system files like `/etc/hosts`
- Treat long periods of no activity as sleep

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

Instead of UI, I've opted to a simple HTTP API that can be used to power a [Raycast](https://www.raycast.com/iloveitaly/hyper-focus)-based UI.

- `/pause` pause the currently running schedule
- `/override` force a blocking profile to run for a period of time
- `/ping` is this thing on?
- `/configurations` array of names of all blocking profiles. To change the order of the results, change the order of the inputs in your config file.

## Development

- Run the binary manually `swift run`
- Copy local config `cp ./config.json ~/.config/focus/config.json`
- Generate a new release `git tag v0.1.3 && git push --tags origin HEAD`

## Tests

Haha! Nope.

This is a fun personal tool. Tests are boring, so I didn't write them.

Plus, writing tests in Swift seems to be a massive pain (no dynamic mocks!).

## Inspiration

- https://github.com/qiuosier/SleepTight
- https://heyfocus.com
- https://github.com/ActivityWatch/aw-watcher-window
