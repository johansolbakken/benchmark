hello:
	echo "setup, feed, prepare"

setup:
	ruby benchmark.rb --setup

feed:
	ruby benchmark.rb --feed

prepare:
	ruby benchmark.rb --prepare-mysql

run_all:
	find job -type f -name '[0-9]*[a-z].sql' | sort | xargs -I {} ruby benchmark.rb --run {} --tree

fresh: setup feed prepare
