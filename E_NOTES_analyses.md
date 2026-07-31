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

H2: Managers are more conservative than other occupation groups

H3: Tech Managers are less conservative than other managers

H4: While Managers in general shifted to the left in recent years, tech managers kept always on the right of the tech firms

Own hypothesis:

H6: "While the majority of tech employees became more liberal from Trump to Biden, there is a trend in Managers that shifted towards the Republicans in the 2024 presidential campaign"

These: für Eliten ist Identity-Politics zwar wichtig, wenn es aber um ihre eignen ökonomischen Interessen geht, ist es ihnen auch schnell wieder zu viel => basically: [Lina Khan](https://en.wikipedia.org/wiki/Lina_Khan) made them go republican... (even though republicans are continuing the aggressive antitrust policies started under Biden)

## Contributors:

It is possible to say something on H1-3 with this data alone.

### Descriptives:

**Compare Industries**: Comparing ideological distributions between sectors visually.

- Dummys don't give many insights
  - why does ff12 have so many NAs? #problem
  - seems to have to do something with case_when / ifelse!
- boxplots tells more information
  - Is there a meaningful difference in ff12 and ff49?
- best are densities!
  - always removes data points because outside of the range - that should be no problem on the full dataset
  - shows that outliers might be a problem - it is not necessarily between -2 and 2!

### Inferential:

The models that run on aggregated data should provide similar measures to 




## OLD

### Overview

Null


### Univariate regressions: occupation ~ industry

Comparing the different operationalizations of "tech sector" by calculating univariate regressions.


Generally, the tech sector is more oriented to the left than other sectors and than the general population. All of the three tech sectors of ff49 are more democrat (in this sample). The ritter-dummy explains more variance of the ideology than the ff49-dummy -> that doesn't mean, that it fits the problematic better though, this has to be judged based on theory! Also, including all of the sectors naturally increases the explanation of variance.

Now, looking at the NAs and performances of the models:




Computing is_tech via Ritter or ff49 classification doesn't change much. Including the sector_ff49 variable changes a lot however - $R^2$ is 0.215!

### Univariate regressions: cfscore ~ occupation

Before computing multivariate regressions, first looking on the occupation variable:


The imbalance in count between "other" and the other two groups could be a problem. Sadly, the same holds true in the Tech industry:


This could have two reasons:

1. The operationalization of the occupational classes is not good - there is some margin for improvement, but not much. This is a typical limitation of my work which has to be accounted for in the interpretation
2. There is a real imbalance which has to be accounted for theoretically

Let's fit the model only for engineers and managers then:


This shows a similar result. There is however another problem: The skew!


### Multivariate regressions: cfscore ~ occupation + industry

Using industry-dummies first:



**Questions**: 

- What is the ideology of different occupations? 
- How much is the bias of not being able to fully identify occupation?

=> calculating the ideology distributions of different occupations in different industries



The distribution of ideology inside the firms is completely different when only counting managers and engineers. Controlling on occupation then doesn't change much, it explains a bit more variance but not much. 

Now only looking inside the occupations: (it should be possible to get similar results by fitting a Multilevel model)


When only including "other", the model performs relatively well (R^2 = 0,150), whereas this isn't the case with the other models. Why could that be? I can think of two different reasons:

- Methodological argument: The variance is a lot bigger, this has a statistical impact - it makes the model fit better (but why?) but can be removed
- Theoretical argument: For the operationalization of managers and engineers that I did, the industrial sector doesn't predict the ideology as well as for all of the others



### Univariate regressions: cfscore ~ location

Using city because the zip codes are often NA:


Compute the ideological means per city:


Running regressions:


### Multivariate regressions: combining everything - cfscore ~ industry + gender + occupation + location

Comparison of multiple models. Construction of a common estimation sample is necessary so model comparison becomes possible because the different variables have different NAs that are only omitted if 

Interpretation:

- The omitted rows are 3.724% which is not that much
- For the interpretation of the R2 see [this website](https://easystats.github.io/performance/articles/r2.html#marginal-vs--conditional-r2)
- m6 performs the best in model comparison
    - when does overfitting become a problem?
- Interestingly, when including gender the effects of occupation get bigger. This is because gender also influences occupation choices and industry choices - more men become managers or engineers, work in certain sectors.

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