
test: test-basic test-with-ingress test-with-ingress-tls log-successful-run

test-basic:
	./test/test-basic.sh 

test-with-ingress:
	./test/test-with-ingress.sh 

test-with-ingress-tls:
	./test/test-with-ingress-tls.sh

log-successful-run:
	./build/update-run-log.sh

.PHONY: test test-basic test-with-ingress test-with-ingress-tls log-successful-run
