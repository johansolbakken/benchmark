hello:
	@echo "Hello User, these are the commands:"
	@echo "-----------------------------------"
	@cat Makefile

job-dataset:
	ruby bin/job-download.rb

job-queries:
	ruby bin/job-remove-min.rb

job-order-queries: job-queries
	ruby bin/job-order.rb

job-schema:
	mkdir -p job-schema
	cp -f ./job/schema.sql job-schema
	cp -f ./job/fkindexes.sql job-schema

job-setup: job-schema
	ruby bin/job-setup.rb

job-feed: job-dataset
	ruby bin/job-feed.rb

job-clean:
	rm -rf job-queries job-schema job-order-queries

prepare:
	ruby bin/benchmark.rb --prepare-mysql

run_all:
	find job -type f -name '[0-9]*[a-z].sql' | sort | xargs -I {} ruby bin/benchmark.rb --run {} --tree

experimental-setup:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./sql/experimental_setup.sql

run-file:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 ${DATABASE} < ${FILE}

homemade-setup:
	ruby bin/homemade-setup.rb

TABLE_A_SIZE=10000
TABLE_B_SIZE=10000
homemade-dataset:
	ruby bin/homemade-generate.rb ${TABLE_A_SIZE} ${TABLE_B_SIZE}

homemade-feed: homemade-dataset
	ruby bin/homemade-feed.rb

empty:

test: empty
	ruby test/oohj_test.rb

job-fresh: job-setup job-feed job-queries prepare

clean: job-clean

inline-local:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 ${DATABASE} -e "SET GLOBAL local_infile = 1;" 
