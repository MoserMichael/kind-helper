
test: test-basic test-with-ingress test-with-ingress-tls log-successful-run

test-basic:
	./test/test-basic.sh >test-basic.log 2>&1 

test-with-ingress:
	./test/test-with-ingress.sh >test-with-ingress.logi 2>&1 

test-with-ingress-tls:
	./test/test-with-ingress-tls.sh >test-with-ingress-tls.log 2>&1 

log-successful-run:
	./build/update-run-log.sh

.PHONY: test test-basic test-with-ingress test-with-ingress-tls log-successful-run
