# Common-mode benchmark. Full run: 600 trials per class per family, 1000 calibration trials
# (about 7 minutes per family on one core). Smoke: N=30 CAL=200.
N   ?= 600
CAL ?= 1000
.PHONY: run smoke plate
run:
	OMP_NUM_THREADS=1 python3 -W ignore bench.py $(N) $(CAL) E47
	OMP_NUM_THREADS=1 python3 -W ignore bench.py $(N) $(CAL) Cube
smoke:
	OMP_NUM_THREADS=1 python3 -W ignore bench.py 30 200 E47
	python3 -c "import json;R=json.load(open('results_E47.json'))['results']['E47']['table'];\
	bad=[(c,p) for c,row in R.items() for p in ('+auditor','auditor-select') if row[p]['k_transfer'] and not c.startswith('CM6')];\
	fa=R['legit']['+auditor']['k_alarm'];print('auditor transfers outside CM6:',bad,' auditor false alarms:',fa);assert not bad and fa==0"
plate:
	python3 plates/plates.py bench results_E47.json results_Cube.json plates/plate_common_mode_benchmark.png
	python3 plates/plates.py falsification ../../formal/e47/native-residual/falsification_results.json plates/plate_theorem_G_falsification.png
