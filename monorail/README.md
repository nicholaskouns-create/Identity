# Elevated Reproducibility Monorail

The gestalt corpus, as a single page. No build. No server required for the browser app. The Richardson contraction on that page is the same recurrence as `formal/e47/richardson/richardson_sim.py`.

## In a browser

Published copy:

https://nicholaskouns-create.github.io/Identity/monorail/

From a clone, open `monorail/index.html`, or:

```
python3 -m http.server 8765
```

Then open `http://127.0.0.1:8765/monorail/`.

## The Python run

```
python3 formal/e47/richardson/richardson_sim.py
```

That prints the sector multipliers, the float residual, the Q4.28 residual, and `(15/17)^n`. The captured run is `formal/e47/richardson/RESULTS.txt`.
