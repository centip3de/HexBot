.PHONY: clean all dev

all: bin/intr

dev:
	ln -sf build.sh .git/post-checkout
	ln -sf build.sh .git/post-merge

bin/intr:
	mkdir -p bin
	dmd src/Interpreter/*.d -of"$@"

clean:
	rm -rf bin
