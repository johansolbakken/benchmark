hello:
	echo "setup, feed, prepare"

setup:
	ruby bin/benchmark.rb --setup

feed:
	ruby bin/benchmark.rb --feed

prepare:
	ruby bin/benchmark.rb --prepare-mysql

run_all:
	find job -type f -name '[0-9]*[a-z].sql' | sort | xargs -I {} ruby bin/benchmark.rb --run {} --tree

empty:

test: empty
	ruby test/oohj_test.rb

fresh: setup feed prepare
