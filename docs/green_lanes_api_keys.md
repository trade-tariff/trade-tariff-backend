### API Key Management
To access GL endpoints in the production environment, clients must provide a valid API key. These API keys are
securely stored in AWS Secrets Manager under the secret name backend-green-lanes-api-keys as a JSON blob.

When authorizing a new API client, you should update the JSON file in Secrets Manager by adding the client’s API key
along with their details and the appropriate throttling limits. This ensures that each client has the correct permissions
and rate limits when interacting with the GL endpoints. Throttling limit is set per number of hours specified in period.

```
{
  "api_keys": {
    "<secret>": {
      "name": "Descartes Labs",
      "description": "Descartes Labs integration key",
      "client_id": "dev",
      "client_contact": "example@hmrc.com",
      "client_secret": "<secret>",
      "t&c_accepted": true,
      "limit": 100,
      "period": 1
    }
  }
}
```