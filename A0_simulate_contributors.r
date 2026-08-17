# INCOMPLETE!

library(tidyverse)

n_sims <- 1000
n_girls <- rep(NA, n_sims)
for (s in 1:n_sims){
  birth_type <- sample(c("fraternal twin","identical twin","single birth"),
  size=400, replace=TRUE, prob=c(1/125, 1/300, 1 - 1/125 - 1/300))
  girls <- rep(NA, 400)
  for (i in 1:400) {
    if (birth_type[i]=="single birth") {
    girls[i] <- rbinom(1, 1, 0.488)
    } else if (birth_type[i]=="identical twin") {
    girls[i] <- 2*rbinom(1, 1, 0.495)
    } else if (birth_type[i]=="fraternal twin") {
    girls[i] <- rbinom(1, 2, 0.495)
    }
  }
  n_girls[s] <- sum(girls)
}

hist(n_girls)


N <- 10
male <- rbinom(N, 1, 0.48)
height <- ifelse(male==1, rnorm(N, 69.1, 2.9), rnorm(N, 63.7, 2.7))
avg_height <- mean(height)
print(avg_height)
class(male)

height_sim <- function(N){
  male <- rbinom(N, 1, 0.48)
  height <- ifelse(male==1, rnorm(N, 69.1, 2.9), rnorm(N, 63.7, 2.7))
  mean(height)
}

hist(z <- replicate(1000, height_sim(10)))

mean(z)
quantile(z, c(0.25, 0.75))
median(z)

abs()