# in order to create the occupation lists to perform regex queries on the occupation variable

# FOR THE MOMENT IT DOESN'T LOOK UP THE OCCUPATIONS AND SAVES THEM IN A SPECIAL FILE - IN FINE IT SHOULD DO THAT!!

# describes functions ----------------------------------------------------

get_engineer_list <- function(){
    # checks if there is a save of lists
    # look up corresponding lists
    # saves corresponding lists
    # FOR NOW ONLY RETURNS A LIST
    list <- c(
        "engineer",
        "data scientist"
    )
    return(list)
}

get_manager_list <- function(){
    # checks if there is a save of lists
    # look up corresponding lists
    # saves corresponding lists
    # FOR NOW ONLY RETURNS A LIST
    list <- c(
        "manager",
        "ceo",
        "cfo",
        "president",
        "director"
    )
    return(list)
}