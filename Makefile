hello:
	@echo "Hello User, these are the commands:"
	@echo "-----------------------------------"
	@cat Makefile

job-dataset:
	ruby bin/job-download.rb

job-queries:
	ruby bin/job-remove-min.rb

job-synthetic: empty
	ruby bin/job-generate.rb -o job-synthetic

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

job-warmup:
	ruby bin/job-warmup.rb

job-analyze:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 imdbload < ./sql/analyze_job.sql

job-index-enable:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 imdbload < ./sql/enable-job-indexes.sql

job-index-disable:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 imdbload < ./sql/disable-job-indexes.sql

job-order-all-queries: job-queries
	ruby bin/job-all.rb

job-plan-png: job-order-all-queries
	mkdir -p job-plan-png
	@for f in job-synthetic/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby bin/print-plan-as-graphwiz.rb $$f -o./job-plan-png/$$base.png --hint "/*+ SET_OPTIMISM_FUNC(SIGMOID) */" --truncate || exit 1; \
	done

job-clean:
	rm -rf job-queries job-schema job-order-queries

prepare: experimental-setup

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

tpc-h-setup:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./tpc-h-schema/schema.sql

tpc-h-feed:
	ruby bin/tpc-h-feed.rb

tpc-h-analyze:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./sql/analyze_tpc_h.sql

tpc-ds-setup:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./tpc-ds-schema/tpcds.sql

tpc-ds-feed:
	ruby bin/tpc-ds-feed.rb

tpc-ds-analyze:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./sql/analyze_tpc_ds.sql

ssb-setup:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./ssb-schema/schema.sql

ssb-feed:
	ruby bin/ssb-feed.rb

ssb-analyze:
	../mysql-server-build/build-release/bin/mysql -uroot --host 127.0.0.1 --port 13000 < ./sql/analyze_ssb.sql


job-plans:
	mkdir -p job-plans && \
	for f in job-order-all-queries/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby bin/print-plan-as-graphwiz.rb --baseline --truncate --database imdbload -o job-plans/$${base}_baseline.pdf $$f; \
	  ruby bin/print-plan-as-graphwiz.rb --oohj     --truncate --database imdbload -o job-plans/$${base}_oohj.pdf     $$f; \
	done

ssb-plans:
	mkdir -p ssb-plans && \
	for f in ssb-queries/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby ./bin/print-plan-as-graphwiz.rb --baseline --truncate --database ssb_s1 -o ./ssb-plans/$${base}_baseline.pdf $$f; \
	  ruby ./bin/print-plan-as-graphwiz.rb --oohj     --truncate --database ssb_s1 -o ./ssb-plans/$${base}_oohj.pdf     $$f; \
	done


stq-plans:
	mkdir -p stq-plans && \
	for f in stress-test-queries/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby bin/print-plan-as-graphwiz.rb --baseline --func ALWAYS --truncate --database imdbload -o stq-plans/$${base}_baseline.pdf $$f; \
	  ruby bin/print-plan-as-graphwiz.rb --oohj     --func ALWAYS --truncate --database imdbload -o stq-plans/$${base}_oohj.pdf     $$f; \
	done

tpc-ds-plans:
	mkdir -p tpc-ds-plans && \
	for f in tpc-ds-queries/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby bin/print-plan-as-graphwiz.rb --baseline --truncate --database tpcds_s10 -o tpc-ds-plans/$${base}_baseline.pdf $$f; \
	  ruby bin/print-plan-as-graphwiz.rb --oohj     --truncate --database tpcds_s10 -o tpc-ds-plans/$${base}_oohj.pdf     $$f; \
	done


explain-job:
	mkdir -p explain-job && \
	total=$$(ls job-order-all-queries/*.sql | wc -l); \
	i=1; \
	for f in job-order-all-queries/*.sql; do \
	  echo "Processing file $$i of $$total: $$f"; \
	  base=$$(basename $$f .sql); \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */" --database imdbload > explain-job/explain_$${base}_baseline.txt; \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.8) */" --database imdbload > explain-job/explain_$${base}_oohj.txt; \
	  i=$$((i+1)); \
	done


explain-ssb:
	mkdir -p explain-ssb && \
	for f in ssb-queries/*.sql; do \
	  base=$$(basename $$f .sql); \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */" --database ssb_s1 > explain-ssb/explain_$${base}_baseline.txt; \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.8) */" --database ssb_s1 > explain-ssb/explain_$${base}_oohj.txt; \
	done

explain-stq:
	mkdir -p explain-stq && \
	total=$$(ls stress-test-queries/*.sql | wc -l); \
	i=1; \
	for f in stress-test-queries/*.sql; do \
	  echo "Processing file $$i of $$total: $$f"; \
	  base=$$(basename $$f .sql); \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */" --database imdbload > explain-stq/explain_$${base}_baseline.txt; \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" --database imdbload > explain-stq/explain_$${base}_oohj.txt; \
	  i=$$((i+1)); \
	done

explain-stq/explain_stq2_oohj_1.0_256KB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 256KB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq2.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq2_oohj_1.0_4MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 4MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq2.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq2_oohj_1.0_6MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 6MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq2.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_1.0_256KB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 256KB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_1.0_2MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 2MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_1.0_4MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 4MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_1.0_6MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 6MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(1.0) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_0.6_2MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 2MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.6) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_0.6_4MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 4MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.6) */" \
	  --database imdbload > $@

explain-stq/explain_stq3_oohj_0.6_6MB.txt:
	mkdir -p explain-stq
	ruby bin/set-join-buffer-size.rb 6MB
	ruby bin/benchmark.rb \
	  --run stress-test-queries/stq3.sql \
	  --analyze \
	  --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.6) */" \
	  --database imdbload > $@


hello-stq3: \
  explain-stq/explain_stq3_oohj_1.0_256MB.txt \
  explain-stq/explain_stq3_oohj_1.0_2MB.txt \
  explain-stq/explain_stq3_oohj_1.0_4MB.txt \
  explain-stq/explain_stq3_oohj_1.0_6MB.txt \
  explain-stq/explain_stq3_oohj_0.6_2MB.txt \
  explain-stq/explain_stq3_oohj_0.6_4MB.txt \
  explain-stq/explain_stq3_oohj_0.6_6MB.txt
	@echo "All explain outputs for STQ3 are generated."

explain-tpc-ds:
	mkdir -p explain-tpc-ds && \
	total=$$(ls tpc-ds-queries/*.sql | wc -l); \
	i=1; \
	for f in tpc-ds-queries/*.sql; do \
	  echo "Processing file $$i of $$total: $$f"; \
	  base=$$(basename $$f .sql); \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ DISABLE_OPTIMISTIC_HASH_JOIN */" --database tpcds_s10 > explain-tpc-ds/explain_$${base}_baseline.txt; \
	  ruby bin/benchmark.rb --run $$f --analyze --hint "/*+ SET_OPTIMISM_FUNC(LINEAR) SET_OPTIMISM_LEVEL(0.8) */" --database tpcds_s10 > explain-tpc-ds/explain_$${base}_oohj.txt; \
	  i=$$((i+1)); \
	done

