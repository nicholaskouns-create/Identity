# E47 kernel certificate -- compiles with the Coq standard library only.
# The three upstream modules are copied UNCHANGED from formal/e47/ into _build/ (as the
# repository's other Coq workflows do), then the generated data and the certificate.
COQC  ?= coqc
BUILD := _build
DEPS  := ../E47MatrixProjector.v ../E47OddsContraction.v ../E47OddsLink.v
EXPECT := 16

.PHONY: check regen clean
check:
	@mkdir -p $(BUILD)
	cp $(DEPS) E47KernelCertificateData.v E47KernelCertificate.v $(BUILD)/
	cd $(BUILD) && $(COQC) -q E47MatrixProjector.v
	cd $(BUILD) && $(COQC) -q E47OddsContraction.v
	cd $(BUILD) && $(COQC) -q E47OddsLink.v
	cd $(BUILD) && $(COQC) -q E47KernelCertificateData.v
	cd $(BUILD) && $(COQC) -q E47KernelCertificate.v | tee assumptions.txt
	@n=$$(grep -c 'Closed under the global context' $(BUILD)/assumptions.txt); \
	 if [ "$$n" -ne $(EXPECT) ]; then echo "FAIL: $$n of $(EXPECT) theorems closed"; exit 1; fi; \
	 echo "OK: all $(EXPECT) Print Assumptions report 'Closed under the global context'"

# Rebuild the witnesses from scratch and require byte-identical output.
regen:
	python3 gen/gen_certificate.py
	python3 gen/emit_coq_data.py
	git diff --exit-code -- gen/certificate.json E47KernelCertificateData.v
	@echo "OK: witnesses regenerate byte-identically"

clean:
	rm -rf $(BUILD)
