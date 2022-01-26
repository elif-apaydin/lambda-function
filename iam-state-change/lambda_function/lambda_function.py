import json, requests
from requests.structures import CaseInsensitiveDict

def lambda_handler(event, context):
    webhook_url = "<SLACK-WEBHOOK-URL>"
    alertUrl    = "<OPSGENIE-URL>"
    eventName   = event['detail']['eventName']
    user        = event['detail']['userIdentity']['userName']
    ip          = event['detail']['sourceIPAddress']
    region      = event['detail']['awsRegion']
    
    if user != '<USERNAME>':
        slack_data = { 'text': "\n*IAM EVENT :alert_: * " + "\n*`Event Name:`*  " + eventName + "\n*`User:`* " + user + "\n*`IP:`* " + ip + "\n*`Region:`* " + region}
        response = requests.post(
            webhook_url, data=json.dumps(slack_data),
            headers={'Content-Type': 'application/json'}
        )

        headers = CaseInsensitiveDict()
        headers["Content-Type"] = "application/json"
        headers["Authorization"] = "GenieKey 8e334dc4-0339-437b-a265-ccf56ac96dba"

        data = """
        {
            "message": "IAM Change Event",
            "alias": "An unauthorized user has taken action.",
            "description":"Please check the IAM Console"
        }
        """

        resp = requests.post(alertUrl, headers=headers, data=data)
        print(resp.status_code)
    
        if response.status_code != 200:
            raise ValueError(
                'Request to slack returned an error %s, the response is:\n%s'
                % (response.status_code, response.text)
        )

    return {"status": 200}