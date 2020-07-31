
test: test-basic test-with-ingress

test-basic:
	./test/test-basic.sh 2>&1 | tee test.log

test-with-ingress:
	./test/test-with-ingress.sh 2>&1 | tee test-with-ingress.log


.PHONY: test test-basic test-with-ingress
