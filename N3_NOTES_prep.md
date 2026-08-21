---
bibliography: refs.bib
--- 

# Notes on B3: computes general quantities of interest to use

## Overview

This document is a summary of the preparation files A3 and B3. It is intended to summarize the notes made on both of the files individually in order to being copied into the Ausformulierung directly. It should, at one point, replace what is written in the Schreibplan now.

It should also include an overview of the robustness as assessed in A4 and B4.

## Filter

Filter for individuals -> no companies, organizations, ...

#incertainty: filter for people that did more >= 3 donations?

## Firms and Industry

- Building a matcher from a bulk file of all applications to SEC Edgar on the internet
    - explain the algorithm (broadly)
- Matching the firms to a SIC code using Jarow-Winkler distance
    - Which threshold to choose for a match to being reliably accepted without having too many false positives? #incertainty
    - Robustness of the matches

### Ausformulierung

In order to a) disambiguate the firms and b) retrieve more information on the firms (such as industry classification, size, revenue, ...) the self-reported employers are being matched against another database. Other papers mostly use commercial databases, like CapitalIQ @short or BoardEx @short, website which I can't access @steel. Other disambiguation methods, like @anconaNovelMethodologyDisambiguate2023 exist, but I couldn't make them work on my data.

The solution I found was, taking a list of public companies, since this one is publically available and disambiguating against that. Since this list also includes the possibility to assign SIC-Codes, I also do that, which provides me with one more variable, even though more sophisticated information isn't available. This enables further classification of the industry as shown in the next paragraph.

Since there is no ready-to-use table of all of the public companies, I had to construct one myself. This was done by downloading the bulk file of applications from the @SEC website and then building the table to match against, containing the companies name and the SIC-Code.

From the SEC, the api is called EDGAR
1.5 GB zip bulk file
=> 72677 names each with one SIC-Code

_On the record linking process itself:_

The process of record linkage here is not trying to hold up to standards required by the record linkage methodology literature [as for example outlined in @Elmagarmid]. I still tried to follow the four necessary steps identified by @Schnell as much as was possible in order to come to a at least somewhat robust matching database:

- preprocessing
    - no parsing @elmagarmid
    - data standardisation: normalized the names from the SEC and the reported names by removing a set of Regex and converting the strings to lower case, but not much more.
    - no need for identification of similar fields, it's already clear!
- Blocking
    - no blocking on my part, I compare the full 72677 companies with the full X rows of the dataset => I don't have meaningful variables to block on
- computing similarity measures
    - First I matched directly
    - Then I chose the Jaro-Winkler (from now on "JW") distance because it is a very common measure to do record linkage with @Schnell. Other measures might have been better suited for this practice but I chose JW for reasons of simplicity.
- estimating thresholds when to accept the measures
    - Iterative process, I adjusted the threshold at which to accept the match automatically (called *strict_dist* in the code) until the share of false positives was smaller than 5%, validated by hand.
    - Robustness: Report the rates of false positives for 3 different thresholds here! Report the rates of false negatives as well! => this can be done in the B4!
- Robustness: compare the matching with the real share of american employees working in public companies! => even though this probably doesn't say much because there might be other reasons for why they are less represented in the data, it gives an impression of how far off I am!

Implications for analysis:

- I am thus limiting my analysis to only public enterprises, which limits its scope dramatically - VC money doesn't go into public enterprises, I only count startups when they're public.
- include an overview of SIC vs NAICS - SIC is a little bit out of date, but is still used in research. I would have preferred NAICS but I couldn't choose.

### Tech Industry - What even is the tech industry?

- Reference to _What even is the "Tech industry"?_

- Only code "the tech sector": Ritter
    - show why I didn't choose this option

- Holistic industry classifications: FF12 vs. FF48 vs. FF49
    - show why ff12 and ff49 have their place and ff48 is misplaced
    - => graphics! I will use ff49

- Robustness? #incertainty
    - Show that a set of companies thought of as "Tech" are actually in the "Tech" category!
    - Compare the share of different industries with the actual shares of industries in the US - are the over-representations reasonable? Where do they come from? (higher income, higher share of public companies, ...)

## Occupation

#incertainty

- Quick overview of disambiguition algorithms for occupations

- Regex engineer, manager (other)

- Maybe Selling/Strimling type but not done yet, might not do it at all

- Robustness?
    - hand code and report the rates of false positives / negatives

## Dynamic CF-Scores

#incertainty

- Why do them? => necessary for a panel-database

- Bonica 2014

- Steel

- What did I do concretely?
    - different from the other two?

## Local ideological means

- mean per zipcode vs. mean per city

- dynamic cfscore means per zipcode/city?

- validity: 
    - density
        - compare the two different ways of calculating the mean per zipcode (contributions and contributors)
        - compare the dynamic cfcsore means per cycle:
            - following @short, it should also polarize!
    - make a map
        - total: compare the means based on contributions and contributors
        - dynamic cfscore means: compare the years
            - => does something shift? some regions shifting ideology meaningfully? does it all look the same?

## Gender

Gender is already included in the DIME-Dataset, I don't have to change anything.

Overview: Report the general gender distribution of donors of different industries? (image)