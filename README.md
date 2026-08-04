# README

Overview over the current state of the code of this Bachelors Thesis project. Some comments on how this is constructed:

- Data has to be created from scratch by running main.r
- In main.r, the flag `run_on_sample` tells A3, E1 and E2 whether to run on a sample of 250.000 or not. Default TRUE.
- The scripts starting with AH are helper scripts containing functions used in A3. They are mostly written by Claude.
- Comments on methodological choices in A3 are in the markdown [A3_NOTES_DIME_compute_QOIs.md](A3_NOTES_DIME_compute_QOIs.md), as are comments on E1 and E2 in [E_Notes.md](E_Notes.md)
    - A3: There are multiple caveats in the construction of the database, e.g. the list for occupation regex isn't finished yet. See the markdown
    - E1: More or less complete, I honestly don't know what kind of descriptive analysis is needed more.
    - E2: incomplete and a total work in progress. My main focus right now is to produce meaningful analysis in line with the hypotheses right now.
- The next goal will be to construct time line data. I found a paper that does exactly that, so I can just copy most of the code and tweak it (because he doesn't use duckdb and merges it with a private data source in order to get information on employer and more): https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/ES0YIJ

## Hypotheses:

Testing previous / obvious findings:

H1: Tech employees are on average more liberal than employees in other firms

H2: Managers are more conservative than other occupation groups

H3: Tech Managers are less conservative than other managers

H4: While Managers in general shifted to the left in recent years, tech managers kept always on the right of the tech firms

Own hypothesis:

H6: "While the majority of tech employees became more liberal from Trump to Biden, there is a trend in Managers that shifted towards the Republicans in the 2024 presidential campaign"

## Fragen:

1. Thema Firmen Matches: Wie soll ich die Settings da setzen? Ich kann das nicht von Hand validieren
2. Thema occupation matches: sind regex die richtige Wahl, oder soll ich wieder mit stringdist("jw") arbeiten?
3. War duckDB hier wirklich nötig? [Steel (2026)](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/ES0YIJ) verwendet es nicht (in dem README steht aber auch, dass er 96 GB RAM hat...)
4. Soll ich mehr deskriptive Analysen machen? Ehrlicherweise weiß ich nicht, was ich noch machen kann...
5. Wie vergleicht man Multilevelmodelle am besten?
6. Fixed effects oder Multilevel-Modell? Bisherige Arbeiten entscheiden je nach research Interesse:
	- [@steelPoliticalTransformationCorporate2026; sellingLiberalAntiestablishmentExploration2023] use only fixed effects models and incorporate geography as a local ideological mean => only as a control variable!
	- [@shortPoliticsAmericanKnowledge2022] uses multi level => as the main treatment variable!
    - => Mein Interesse wäre ja eigentlich auch nur als control variable, aber ich habe das noch nie gemacht! Ich müsste mich nochmal ein wenig einlesen - würde es auch gehen, multilevel modelle für zwei Zeitpunkte (2016 und 2024, theoretisch begründet) zu berechnen und diese zu vergleichen? Das wäre viel einfacher, da wir Multilevelmodelle im Kurs mehr behandelt haben und ich mich da auch ein bisschen mehr reingelesen habe.
7. Wann wird overfitting zum Problem? In Bezug auf [m6 der Multilevelregressionsvergleiche](/E2_inferential.R)
8. Soll ich so schreiben wie ein Paper (d.h. relativ kurz für Theorie, Methodik, Findings und die genauen Details zu computation von Variablen, tests und anderen methodischen Entscheidungen in einen Anhang), oder ist ein einziger Fließtext mit diesem Github als Code Repo am angebrachtesten? Derzeit schreibe ich letzteres.
9. Wie ernst soll ich die Validierung / Robustness der Ergebnisse nehmen?
