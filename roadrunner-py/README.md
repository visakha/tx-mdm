# roadrunner-py - tx-mdm desktop test runner (0.10.0)

Runs the tx-mdm test use cases from your Windows desktop against the tx-mdm backend
(the Linux box, or your own laptop with --local). It only talks HTTP to the backend.

## What it does, in order
1. Makes one folder per test case (for example `runs\TTF_use-case-1`).
2. Downloads the Excel template into it as `filled.xlsx` (Home sheet first).
3. You fill it (or keep the generated sample data). Expected sheets say what should land.
4. Uploads it, the backend checks it first (pre-flight), then runs the steps.
5. Pauses at manual steps (prepare Excel, ingress, egress, MDM job):
   `[1] Done (Enter)  [2] Retry  [3] Skip  [4] Abort` - type the number or the word.
6. After Done it asks the backend whether the step really finished (row counts).
7. Writes the result workbook and the run log into the same folder.

It never deletes or cleans up test data. That is yours.

## First time (PowerShell, from the tx-mdm folder)
    cd roadrunner-py
    .\run.ps1 help

`run.ps1` makes `.venv` and installs roadrunner the first time.

## Everyday commands
    .\run.ps1                                   # start menu: [1] Help [2] Run [3] Quit
    .\run.ps1 help TTF use-case-9               # sheets + story of one use case
    .\run.ps1 init TTF use-case-9 --rows 6      # folder + generated template (--empty for blank)
    .\run.ps1 run TTF use-case-9                # run it, pausing at manual steps
    .\run.ps1 run TTF --all                     # every TTF use case
    .\run.ps1 resume TTF use-case-9 <run_id>    # continue a run (state is on the server)
    .\run.ps1 --auto test                       # the BDD features (Gherkin) = the tests

Where the backend is: `--base-url http://<server>:8000` or `$env:TXMDM_BASE_URL`.
Default path is mock (`/api/test/mock/...`). `--real` uses `/api/test/...` (real services;
it reports NOT_CONFIGURED until the placeholders in backend/test_cases/test_config.toml are real).

## Laptop only (dry run, nothing leaves the laptop)
    .\run.ps1 --local --auto run TTF --all
    .\run.ps1 --local --auto test

`--local` starts the backend from `..\backend` with its own `.venv` on port 8765 (mock path).

## Scripted answers
Each test-case folder has `answers.toml`:

    [answers]
    "prepare-excel" = "done"
    "ingress" = "HUMAN"
    "egress" = "done"

Values: done / retry / skip / abort, or HUMAN = ask a person at that pause.
`--auto` (or `$env:TXMDM_BDD_AUTO = "1"`) takes Done everywhere.

## Checks (for changes to the runner)
    .\.venv\Scripts\ruff.exe check .
    .\.venv\Scripts\ruff.exe format --check .
    .\.venv\Scripts\pyrefly.exe check
