#!/bin/bash
# OktaGroupSearch v0.2 20220611
# Rewrite of my oktaGroupSearch bash function:
###  oktaGroupSearch ()
###  {
###      read -p "Okta Group Name: " GNAME;
###      oktaGet "https://${oktaOrg}/api/v1/groups?q=${GNAME}" | jq '.[]| {id, name: .profile.name}'
###  }

#VARs
# Get Okta org instance FQDN if defined; otherwise use example.okta.com
oktaOrg="${oktaOrg:-example.okta.com}"
api_token="${api_token:-CHANGE_THIS_TO_YOUR_TOKEN}"

oktaGroupSearch () 
{ 
    # Prompt for a group search criteria if one is not provided on invocation.
    groupName=${1:-$(read -p "Okta Group Search Query: " x; echo "${x}")};
    # Create a temp file to process response header for the rel=next link
    fntmpfile="$(mktemp /tmp/${FUNCNAME[0]}_XXXXXX)";
    # I only care about a subset of the group attributes, so I use jq to to tidy up/summerize the response
    curl --show-error --silent -H "Authorization: SSWS ${api_token}" --dump-header "$fntmpfile" "https://${oktaOrg}/api/v1/groups" --url-query "limit=600" --url-query 'sortBy=profile.name' --url-query 'expand=stats' --url-query "search=profile.name sw \"${groupName}\"" | jq '.[] | {id, created: .created, lastUpdated: .lastUpdated, lastMembershipUpdated: .lastMembershipUpdated, name: .profile.name, description: .profile.description, stats: { usersCount: ._embedded.stats.usersCount, appsCount: ._embedded.stats.appsCount, hasAdminPrivilege: ._embedded.stats.hasAdminPrivilege } }';
    # Check for a "next" link in the last response header(tmpfile). If it exists create a new tmp file we'll key off of
    # grep info: ggrep == gnu/grep (brew), -P == PCRE (Perl Regex), -o == only return matched pattern
    # regex info: Match using a positive lookbehind (?<=...) begining of line "link: <" match everything but the closing ">" and only if 
    #   positive lookahead (?=...) has our rel=next criteria 
    # logic info: If a next link is found, we store it in another tmp file, otherwise we rm the new empty temp file.
    ggrep -Po '(?<=^link: <)[^>]*(?=.*"next")' ${fntmpfile} > ${fntmpfile}.next || rm ${fntmpfile}.next;
    # Repeat until we no longer get a response header with a rel="next" link.
    while [[ -e ${fntmpfile}.next ]]; do
        echo "Sleeping before making next API call [${fntmpfile}.next]" 1>&2;
        sleep 2 || sleep 22;
        curl --show-error --silent -H "Authorization: SSWS ${api_token}" --dump-header "$fntmpfile" "$(tail -n1 ${fntmpfile}.next)" | jq '.[] | {id, created: .created, lastUpdated: .lastUpdated, lastMembershipUpdated: .lastMembershipUpdated, name: .profile.name, description: .profile.description, stats: { usersCount: ._embedded.stats.usersCount, appsCount: ._embedded.stats.appsCount, hasAdminPrivilege: ._embedded.stats.hasAdminPrivilege } }';
        ggrep -Po '(?<=^link: <)[^>]*(?=.*"next")' ${fntmpfile} > ${fntmpfile}.next || rm ${fntmpfile}.next;
    done
}
