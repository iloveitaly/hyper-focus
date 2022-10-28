.PHONY: build test package clean

build:
	make build-swift;

build-swift: focus

focus: focus.swift
	swiftc $^ -o $@

clean:
	rm focus
