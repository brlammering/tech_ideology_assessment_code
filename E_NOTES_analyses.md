---
bibliography: refs.bib
format: 
  html:
    toc: true
    code-fold: false
---

# Notes on the Analyses

## Overview:

Testing previous / obvious findings:

H1: Tech employees are on average more liberal than employees in other firms

- Descriptive Dummy is_tech
- Descriptive Comparisons of ff49

H2: Managers are more conservative than other occupation groups

H3: Tech Managers are less conservative than other managers

H4: Managers in general shifted to the left in recent years

H5: Tech managers kept always on the right of the tech firms

Own hypothesis:

H6: "While the majority of tech employees became more liberal from Trump to Biden, there is a trend in Managers that shifted towards the Republicans in the 2024 presidential campaign"

These: für Eliten ist Identity-Politics zwar wichtig, wenn es aber um ihre eignen ökonomischen Interessen geht, ist es ihnen auch schnell wieder zu viel => basically: [Lina Khan](https://en.wikipedia.org/wiki/Lina_Khan) made them go republican... (even though republicans are continuing the aggressive antitrust policies started under Biden)

I don't standardize even more because Bonica's cfscores come already standardized - on the main sample. Re-standardizing would only limit cover the potential invalidity of the data preparation process.

## Contributors:

It is possible to say something on H1-3 with this data alone.

On the inferential analysis, I conduct multiple regressions on each of the variables to check for what might change (?). They are not exported into results.

### Descriptives:

In the future, the goal is to build beautiful graphics with comparisons in industries and occupations, using popular candidates as comparisons. This is then going to be completed with the descriptives from contributions to show differences in time.

**Compute candidates for comparison**: Not done yet, copied from Steel but not yet adjusted

**Compare occupations**: Not done yet, could be potentially interesting

**Compare Industries**: Comparing ideological distributions between sectors visually.

- Dummys don't give many insights
- boxplots tells more information
  - Is there a meaningful difference in ff12 and ff49?
- densities are best!
  - always removes data points because outside of the range - that should be no #problem on the full dataset
  - shows that outliers might be a #problem - it is not necessarily between -2 and 2!

### Inferential:

The models that run on aggregated data should provide similar fits to the models running on the panel data - if not, why could that be?


### Multivariate regressions: cfscore ~ occupation + industry

**Questions**: 

- What is the ideology of different occupations? 
- How much is the bias of not being able to fully identify occupation?

**Comparing effects of occupation and industry differently from each other by regressing on differently filtered data**

=> is this really the way to go? Maybe include differently filtered data

m1 = full regression

m2 = regression comparing only managers and engineers with each other

m3 = regression only comparing the industries by filtering for managers and engineers

=> Compare the whether and why the coefs of different industries / occupations might differ. If they don't the hypotheses of different industries being a certain ideology are quite robust but it also might mean that occupation doesn't explain much difference!


**Comparison of the industry effects in occupational groups**

=> Goal: compare the different R2 to see how much they are explaining in variance, if that differs for different groups

=> speculate on why it could vary by interpreting the coefficients

### Multilevel regressions without location

In order to see whether it is even useful to build certain models or not:

m0 -> to compute the icc

m1 -> includes ff49 into the second level, fixed slope

m2 -> includes random slopes

=> the goal here is to compare m1 and m2 to see whether accounting for the slopes increases R2 meaningfully, whether σ2 (error on lvl 1) gets smaller, whether τ00 (variance of random intercepts between groups) and τ11 (variance of random slopes between groups) differ. If τ11 differs for the different occupations, there might be some theoretical reason (i.e. managers being closer to one another than "other").


### Univariate regressions: cfscore ~ location

Zipcodes are finer and more equally (although not totally equal) sized - therefore using them instead of cities. They account for more of the data.

Decide here whether it makes a meaningful difference to use zip means or include zip into the multilevel model as a second (independent) level. If it were for a fixed effects model, this question is obvious - use means.


### Multivariate regressions: combining everything - cfscore ~ industry + gender + occupation + location

Constructs a common estimation sample first and check which rows are being filtered out.

=> DO THE CHECK AFTERWARDS, IT IS NOT OBVIOUS TO SEE WHETHER THE COMMON ESTIMATION SAMPLE IS BIASED IN ANY WAY OR NOT!!!

Comparison of multiple models. Construction of a common estimation sample is necessary so model comparison becomes possible because the different variables have different NAs that are only omitted if 

Interpretation:

- For the interpretation of the R2 see [this website](https://easystats.github.io/performance/articles/r2.html#marginal-vs--conditional-r2)
  - also keep in mind that the marginal R2 shows the variance explained by the pooled effects and the conditional R2 shows the variance explained by the pooled effects + the random slopes!

m0, ...: 

- 

s0, ...:

#### Controlling on gender or not?

Interestingly, when including gender the effects of occupation get bigger. This is because gender also influences occupation choices and industry choices - more men become managers or engineers, work in certain sectors. The DAG and the graphic goes to show exactly this.

(It might also be that men are not only more often engineers but that in their self reported occupation they write "engineer" more often because of social status reasons)

Should I control for gender then? I would argue that no, because it conflates the results too much.


### questions

from the model_performance wiki: 

> REML versus ML estimator: The default behaviour of model_performance() when computing AIC or BIC of linear mixed model from package lme4 is the same as for AIC() or BIC() (i.e. estimator = "REML"). However, for model comparison using compare_performance() sets estimator = "ML" by default, because comparing information criteria based on REML fits is usually not valid (unless all models have the same fixed effects). Thus, make sure to set the correct estimator-value when looking at fit-indices or comparing model fits.

Does that mean I cannot really compare the models? Is fitting with ML still possible? -> Patrick


## H2: While the majority of tech employees became more liberal from Trump to Biden, there is a trend in Managers that shifted towards the Republicans in the 2024 presidential campaign

Maybe use GEE (see https://cran.r-project.org/web/packages/panelr/vignettes/wbm.html#Using_GEE_to_fit_within-between_models) instead of using Multilevel models here?

Regress on cfscore or directly on the quantity of donations (n or total money donated)?

Discuss FE Models vs. Multilevel Models



## References