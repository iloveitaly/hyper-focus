SHELL := zsh
.PHONY: build release clean

build:
	swift build -v

release:
	bin/release
	git push --tags origin HEAD

clean:
	rm -Rf .build/
	rm -Rf ~/Library/Developer/Xcode/DerivedData
	rm -Rf /Users/mike/Library/Caches/org.swift.swiftpm
	rm Package.resolved