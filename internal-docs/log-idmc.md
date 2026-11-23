# Misc

Login WebSite: https://dm1-us.informaticacloud.com/identity-service/home

service URL: https://usw1.dm1-us.informaticacloud.com/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic


# Invoking the Ingress Job by calling the REST API on the taskFlow
we have two options 

## Option 1 GET
GET https://usw1.dm1-us.informaticacloud.com/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic?jobInstanceId=123456

## Option 2 POST
POST https://usw1.dm1-us.informaticacloud.com/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic
Content-Type: application/json
Accept: application/json

{
  "jobInstanceId": "123456"
}




