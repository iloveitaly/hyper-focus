SHELL := zsh
.PHONY: build build-release github-release local-release clean

build:
	swift build -v

build-release:
	swift build -v -c release --arch arm64 --arch x86_64 --disable-sandbox

github-release:
	bin/release

local-release: build-release
	bin/local-release

clean:
	rm -Rf .build/
	rm -Rf ~/Library/Developer/Xcode/DerivedData
	rm -Rf /Users/mike/Library/Caches/org.swift.swiftpm
	rm Package.resolved