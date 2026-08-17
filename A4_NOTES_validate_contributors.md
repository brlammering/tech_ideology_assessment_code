# Validate contributors

## overview

Validates the data by checking for assumptions. Error output if not fulfilled.

## Missings

For now just computes a set where every column is included that has at least one NA.

The goal is to count the different NAs of the columns here and to give out where NAs are, so that one can evaluate whether the data generation had errors or not.

## Inspect occupation

### Univariate regressions: cfscore ~ occupation

The NAs might be a #problem.

The imbalance in count between "other" and the other two groups might be a problem. It doesn't have to be the case though. 


This could have two reasons:

1. The operationalization of the occupational classes is not good - there is some margin for improvement, but not much. This is a typical limitation of my work which has to be accounted for in the interpretation
2. There is a real imbalance which has to be accounted for theoretically

## inspect industry

### Univariate regressions: cfscore ~ industry

Comparing the different operationalizations of "tech sector" by calculating univariate regressions. This could be used for validation of the industry - look whether "tech industry" is similar in all of them!

There is a #problem with the NAs: for some reason ff49 has different NAs than ff49_is_tech. Circumvented the problem with a filter, but only temporary.

## Industry/occupation group sample size

Sanity check whether there are pairings of occupation/ff49 that have very few observations in [results/descriptive_statistics_by_ff49_occupation_smaller_20](/results/descriptive_statistics_by_ff49_occupation_smaller_20). Look if the sd is too dissimilar from the other results.

## Individual outlier

Outlier defined as outside the range -3,3. Error message gives the number of outliers.

## Compare with total dataset 

to see how the subset is different => maybe?