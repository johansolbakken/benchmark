hello:
	@echo "Hello User, these are the commands:"
	@echo "-----------------------------------"
	@cat Makefile

job-dataset:
	ruby bin/download-job-dataset.rb

job-setup:
	ruby bin/setup-job.rb

job-feed:
	ruby bin/feed-job.rb

prepare:
	ruby bin/benchmark.rb --prepare-mysql

run_all:
	find job -type f -name '[0-9]*[a-z].sql' | sort | xargs -I {} ruby bin/benchmark.rb --run {} --tree

empty:

test: empty
	ruby test/oohj_test.rb

job-fresh: job-setup job-feed prepare
