# Card, Chetty & Weber (2007) — Stata Replication Code

> **This was a personal exercise done as part of a course assignment. It is not an official replication package and has not been verified or endorsed by the original authors.**

---

## Data requirements

Three raw data files are required to run the code. They are **not included** in this repository and must be obtained separately:

- `sample_75_02.dta`
- `sample_nebenr.dta`
- `work_history.dta`

Place all three files in `data/raw/` before running any do-file.

You must also create the `data/clean/` directory manually before running `01_build_dataset.do`, as Stata will not create it automatically and the script will fail without it.

---

## Project structure

```
project/
├── data/
│   ├── raw/              ← place the three .dta files here
│   └── clean/            ← create this directory manually
├── output/
│   ├── figures/
│   ├── tables/
│   └── logs/
└── do-files/
    ├── 01_build_dataset.do
    ├── 02_figures.do
    └── 03_tables.do
```

---

## Do-files

Run the scripts in order.

**`01_build_dataset.do`**
Loads `sample_75_02.dta`, merges with `work_history.dta`, applies the sample restrictions from Card, Chetty & Weber (2007), and constructs the running variables, monthly bins, polynomial controls, and censoring indicator. Output: `data/clean/analysis_dataset.dta`.

**`02_figures.do`**
Produces the RD binned-scatter figures. Covers layoff frequency around the severance pay threshold (Figure II), covariate smoothness checks (Figures III, IV), nonemployment duration jumps (Figures V, VIIIa), job-finding hazard plots (Figures VI, VIIIb), and subsequent job quality (Figures Xa, Xb).

**`03_tables.do`**
Estimates the Cox hazard models and exports Table II in both `.tex` and `.csv` formats. Requires `estout` (`ssc install estout`); the script will attempt to install it automatically if missing.

---

## Setup

Before running, open each do-file and update the global path at the top:

```stata
global project "C:/your/path/here"
```

---

## Paper reference

Card, D., Chetty, R., & Weber, A. (2007). Cash-on-Hand and Competing Models of Intertemporal Behavior: New Evidence from the Labor Market. *Quarterly Journal of Economics*, 122(4), 1511–1560.
