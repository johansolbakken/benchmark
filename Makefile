hello:
	echo "setup, feed, prepare"

setup:
	ruby benchmark.rb --setup

feed:
	ruby benchmark.rb --feed

prepare:
	ruby benchmark.rb --prepare-mysql

fresh: setup feed prepare
