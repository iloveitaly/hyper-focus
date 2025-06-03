SHELL := zsh
.PHONY: build build-release github-release local-release clean

trunk:
	trunk upgrade
	trunk fmt

test:
	swift test -vv

build:
	swift build -v

build-release:
	swift build -v -c release --arch arm64 --arch x86_64
	# I had the `--disable-sandbox` flag in place here, but I'm not sure entirely why...

package:
	swift package resolve
	swift package update

github-release:
	bin/release

github-rerelease:
	bin/rerelease

local-release: build-release
	bin/local-release

clean:
	rm -Rf .build/
	rm -Rf ~/Library/Developer/Xcode/DerivedData
	rm -Rf /Users/mike/Library/Caches/org.swift.swiftpm
	rm Package.resolved