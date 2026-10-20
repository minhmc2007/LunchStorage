# LunchStorage local build entrypoint

ORDER = openssl-1.1 ncurses5-compat-libs lib32-ncurses5-compat-libs python2 material-symbols-git libastal-bluetooth-git libastal-wireplumber-git python-materialyoucolor calamares ii-material-sddm-git hypryou hypryou-utils
OUT ?= out/x86_64

.PHONY: all repo pkg check clean
all: repo

repo: pkg

pkg:
	OUT="$(OUT)" bash tools/build.sh "$(ORDER)"

check:
	python3 tools/check.py

clean:
	rm -rf out plan.json packages-to-build.txt
