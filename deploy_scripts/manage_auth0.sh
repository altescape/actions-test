#!/bin/bash
if [ "$1" == "" ] || [ "$2" == "" ]; then
 echo "$0 <add|remove> <origin>"
 echo "Example: $0 add https://neworigin.example.com"
 exit
fi

VAULTNAME="swiftaid-vault-dev"
CLIENTID=$(az keyvault secret show --vault-name ${VAULTNAME} -n auth0-client-id --query value -o tsv)
CLIENTSECRET=$(az keyvault secret show --vault-name ${VAULTNAME} -n auth0-client-secret --query value -o tsv)
SADEV_CLIENTID=$(az keyvault secret show --vault-name ${VAULTNAME} -n auth0-swiftaid-dev-clientid --query value -o tsv)

RESPONSE=$(curl --request POST \
--url 'https://swiftaid.eu.auth0.com/oauth/token' \
--header 'content-type: application/x-www-form-urlencoded' \
--data grant_type=client_credentials \
--data client_id=$CLIENTID \
--data client_secret=$CLIENTSECRET \
--data 'audience=https://swiftaid.eu.auth0.com/api/v2/')
TOKEN=$(echo "${RESPONSE}" | jq ".access_token" | tr -d '"')

RESPONSE=$(curl --request GET \
  --url "https://swiftaid.eu.auth0.com/api/v2/clients/$SADEV_CLIENTID" \
  --header "authorization: Bearer $TOKEN" \
  --header "content-type: application/json")

if [ $1 == "add" ]; then
  echo Adding origin $2
  UPDATED=$(echo "${RESPONSE}" | jq '.web_origins |= (. + ['"\"$2\""'] | unique)')
  UPDATED=$(echo "${UPDATED}" | jq '.allowed_logout_urls |= (. + ['"\"$2\""'] | unique)')
  UPDATED=$(echo "${UPDATED}" | jq '.callbacks |= (. + ['"\"$2/callback\""'] | unique)')
fi

if [ $1 == "remove" ]; then
  echo Removing origin $2
  UPDATED=$(echo "${RESPONSE}" | jq '.web_origins |= (. - ['"\"$2\""'] | unique)')
  UPDATED=$(echo "${UPDATED}" | jq '.allowed_logout_urls |= (. - ['"\"$2\""'] | unique)')
  UPDATED=$(echo "${UPDATED}" | jq '.callbacks |= (. - ['"\"$2/callback\""'] | unique)')
fi

UPDATED=$(echo "$UPDATED" | jq '{web_origins,callbacks,allowed_logout_urls}')

curl --request PATCH \
  -o /dev/null \
  --url "https://swiftaid.eu.auth0.com/api/v2/clients/$SADEV_CLIENTID" \
  --header "authorization: Bearer $TOKEN" \
  --header "content-type: application/json" \
  -d "$UPDATED"
