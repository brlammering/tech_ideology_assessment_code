---
bibliography: refs.bib
--- 

# Notes on A3: computes general quantities of interest to use

## preparation

see the file

## Filter

Filter only individuals that contributed to at least 2 ppl (as did Bonica in order for correct evaluation of the ideal ideological position).

Why do this? It filters out around half of the observations? Because in order to compute the CFScores, the data that serves as a basis should be large enough. Only one datapoint is not sufficient for computing ideology. 2 should be fine, 3 is not enough data points (only half of when filtering for 2) and Bonica is also doing that in his own work @bonica

**INCERTAINTY**: Is this really necessary? 2 seems a little bit random, 3 is what Bonica is actually mentioning in his work (2014). It reduces the sample a lot... # problem

=> skip for now, introduce later to see if there is a meaningful difference!


## Firms and Industry

Disambiguating the firms is a major task. The main problem I have is that I have no list to match against, in order to perform regex or stringdist matches. Other papers mostly use commercial databases, like CapitalIQ @short or BoardEx @short, website which I can't access @steel. Other disambiguation methods, like @anconaNovelMethodologyDisambiguate2023 exist, but I couldn't make them work for my data.

The solution I found was, taking a list of public companies, since this one is publically available and disambiguating against that. Sadly the US doesn't give out such information publically (unlike France e.g. https://data.inpi.fr/). Since this list also includes the possibility to assign SIC-Codes, I also do that, which provides me with one more variable.

I am thus limiting my analysis to only public enterprises, which limits its scope dramatically - VC money doesn't go into public enterprises, I only count startups when they're public.

I let Claude write the code for this, because my own abilities in coding are more than limited. It does the following: download the entire submissions dataset as bulk data, create a table that only includes company name, sic number and sic description and fuzzy match the self assigned names against this table.

### Reliability of matches

This is a table that gives an overview on how many matches are of what type (from a sample of 250000):

|status        | n |
| --- | --- |
NA         |  0.395 
needs_review| 0.272 
no_match     |0.301 
auto_accept  |0.0315

NAs and no matches are dropped immediatly.

I also drop all of the matches that need review, because they are mostly wrong - the chance of getting many false positives is big, the risk in getting false negatives is smaller. However, this includes only around 3% of the sample. 

This is acceptable for a large database and the scope of the thesis. It means that my data accounts for people that work in public firms and that my algorithm caught. I don't think there is big bias involved, it depends on the sloppiness of self-reporting and maybe the difficulty and uniqueness of the firm name. Of course, some firms will be over represented, but that will be the case for all industries - no industry is biased in particular.

I might have to compare it to the real distribution of american employees in order to see the skew - is there data anywhere on that? This would kind of correspond to the match rates that can be evalued when matches are being done with private databases.

## Tech Industry

### First option: only code "the tech sector"

Now that the SIC codes are available, I chose to refer to the sic codes to determine whether a company is part of the "tech sector" or not (see the theoretical explanation above).

I refer myself mostly to classifications from finance. I could use one classification which defines "Tech stocks [...] as internet-related stocks plus other technology stocks including telecom, but not including biotech" @ritterInitialPublicOfferings. This however puts tech in one group and all of the other industries in another - it is very coarse.

> ~~(Tech stocks are defined as those in SIC codes 3571, 3572, 3575, 3577, 3578 (computer hardware), 3661, 3663, 3669 (communications equipment), 3674 (electronics), 3812 (navigation equipment), 3823, 3825, 3826, 3827, 3829 (measuring and controlling devices), 3841, 3845 (medical instruments), 4812, 4813 (telephone equipment), 4899 (communications services), and 7370, 7371, 7372, 7373, 7374, 7375, 7378, and 7379 (software) @loughranWhyHasIPO2004 -> + more stuff see @ritterInitialPublicOfferings  => I might have to manually do some of these: 7389, they're not complete (see claude discussion))~~

=> I don't use this anymore (don't even compute it), since it would lead to me comparing a set of sic codes against _everything else_ - which is impossible to interpret.


### Second option: use classifications spanning the whole SIC

Choice: Fama-French classifications, used as a standard for many other research projects @steel. It provides a mapping from SIC codes in different degrees of sophistication, originally developed to compute finance statistics.

See https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/Data_Library/det_49_ind_port.html for more details.

For Fama-French 49, this would be our definition of Tech: Tech = Hardw, Softw, Chips

**INCERTAINTY**: should I use Fama-French 12? which is better for my purpose? => plot both and compare! #problem

=> eventual researcher degree of freedom here?


### Robustness:

In order to establish robustness of the industry classification, I compare it to other industry classifications sometimes used:

NOT DONE YET #problem

- compare fama-french and ritter (in a table and using example companies)
- Open secrets: @CommunicationsElectronicsSector is their way to go - very coarse - how well does it match tho?
- Fortune500: which of the "technology" classified companies are included in my definition of technology industry?

### Conclusion

Not yet, I am not sure whether I should use a more or less coarse classification. But its gonna be fine, Fama-French 49 is good for the beginning.


## Occupation

In an ideal world, I could use SOC, O*NET or ISCO standart classifications in order to rely on work that has been done on the comparability of roles. There are even possibilities that could assign them automaticalls:

- SOCcer @buckner-pettyEfficiencyAutocodingPrograms2019 @russComputerbasedCodingFreetext2016
- NIOCCS -> @NIOCCSIndustryOccupation

It would however be too difficult to do this. Instead, in order to account for the theoretical arguments I made, I make the main differenciation between technicians, managers and other (e.g. lawyers). They are primarily differenciated in that the managers not only hold more responsability for the projects, they are actively concerned with budgeting.

I created lists of occupations that I query via regex.

**INCERTAINTY**: 

- Does this theoretical distinction hold? How does @Selling motivate that theoretically? #problem
- I didn't develop the full lists yet, how do I do this methodologically correct?

**leaders -> selling!!!**

## Local ideological means

Not done yet, is very important for control tho!

## save data, disconnect from the db
