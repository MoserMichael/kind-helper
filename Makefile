
test: test-basic test-with-ingress test-with-ingress-tls log-successful-run

test-basic:
	./test/test-basic.sh 2>&1 | tee test-basic.log

test-with-ingress:
	./test/test-with-ingress.sh 2>&1 | tee test-with-ingress.log

test-with-ingress-tls:
	./test/test-with-ingress-tls.sh 2>&1 | tee test-with-ingress-tls.log

log-successful-run:
	./build/update-run-log.sh

.PHONY: test test-basic test-with-ingress test-with-ingress-tls log-successful-run
