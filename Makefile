SHELL := /bin/bash

.PHONY: doctor build test package package-unsigned clean

doctor:
	bash scripts/doctor.sh

build:
	swift build

test:
	swift test

package:
	bash scripts/package-app.sh

package-unsigned:
	SKIP_CODESIGN=1 bash scripts/package-app.sh

clean:
	rm -rf .build dist
