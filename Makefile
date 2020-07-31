

test:
	./test/test.sh 2>&1 | tee test.log

.PHONY: test
