EMACS=emacs

.PHONY: check
check:
	$(EMACS) -Q --batch -L . -l sourcegraph -l sourcegraph-tests \
	--eval '(ert-run-tests-batch-and-exit t)'
