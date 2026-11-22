# Native-basis residual certificates (Theorem G, exact half) + the transfer-half falsification.
COQC  ?= coqc
BUILD := _build

.PHONY: check regen falsify clean
check:
	@mkdir -p $(BUILD)
	cp NativeResidualCertificate.v NativeResidualRandomInstance.v $(BUILD)/
	cd $(BUILD) && $(COQC) -q -Q . NR NativeResidualCertificate.v | tee assumptions_general.txt
	cd $(BUILD) && $(COQC) -q -Q . NR NativeResidualRandomInstance.v | tee assumptions_random.txt
	@a=$$(grep -c 'Closed under the global context' $(BUILD)/assumptions_general.txt); \
	 b=$$(grep -c 'Closed under the global context' $(BUILD)/assumptions_random.txt); \
	 if [ "$$a" -ne 6 ] || [ "$$b" -ne 2 ]; then echo "FAIL: $$a/6 and $$b/2 closed"; exit 1; fi; \
	 echo "OK: 6/6 and 2/2 Print Assumptions report 'Closed under the global context'"

# Byte-identical regeneration of every witness that a Coq file or the auditor consumes;
# the certified constants are compared exactly where they are exact (interval endpoints).
regen:
	python3 gen_native.py
	python3 exact_general.py
	git diff --exit-code -- native_instances.json NativeResidualRandomInstance.v random_instance.json
	git show HEAD:./certified_constants.json > /tmp/cc_committed.json 2>/dev/null || cp certified_constants.json /tmp/cc_committed.json
	python3 -c "import json;a=json.load(open('/tmp/cc_committed.json'))['constants'];b=json.load(open('certified_constants.json'))['constants'];assert a==b,'exact constants differ';print('OK: exact constants identical')"

falsify:
	python3 falsify.py $${REPS:-30}
	python3 -c "import json;s=json.load(open('falsification_results.json'))['summary'];print(s);assert s['violations']==0"

clean:
	rm -rf $(BUILD)
