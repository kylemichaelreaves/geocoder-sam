# geocoder-sam

A serverless address-geocoding API built with AWS SAM. A single Ruby Lambda behind
API Gateway takes a US-style address and returns geocoding results (coordinates and
address metadata) from [Geocoder](https://github.com/alexreisner/geocoder)'s default
Nominatim/OpenStreetMap lookup.

## Layout

- `handler/` – Lambda function code (`app.rb`) and its runtime `Gemfile`.
- `handler/spec/` – RSpec unit tests for the handler.
- `events/` – Sample invocation events for `sam local invoke`.
- `postman/` – A Postman collection for exercising the API.
- `template.yaml` – SAM template defining the API, function, and usage plan.

## API

`{GET,POST} /v1/geocode` — protected by resourceQuerier's JWT authorizer. Callers must
send `Authorization: Bearer <jwt>` with a token issued by resourceQuerier's
`POST /api/v1/login`; requests without a valid token get `401`.

The endpoint accepts an address in one of three shapes:

1. **GET with individual query params** (canonical):
   `streetAddress`, `unitOrAptNum`, `municipality`, `state`, `zipcode`
   ```
   GET /v1/geocode?streetAddress=1600%20Pennsylvania%20Ave%20NW&municipality=Washington&state=DC&zipcode=20500
   ```
2. **POST with a JSON body** (RESTful structured input):
   keys `streetAddress`, `aptNum`, `city`, `state`, `zipCode`
   ```
   POST /v1/geocode
   Content-Type: application/json

   {"streetAddress":"208 Anderson St","city":"Hackensack","state":"New Jersey","zipCode":"07601"}
   ```
3. **GET with a JSON `address` query param** (⚠️ deprecated backward-compat shim):
   `GET /v1/geocode?address={"streetAddress":"...","city":"..."}`

### Responses

| Status | When |
|--------|------|
| `200`  | Results found — `{ "message": [ ...geocoder results... ] }` |
| `401`  | Missing or invalid JWT (rejected by the authorizer) |
| `400`  | No address provided, or malformed JSON |
| `404`  | No geocoding results for the address |
| `500`  | Upstream geocoder error |

## Prerequisites

- [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
- Ruby 3.4 (see `.ruby-version`)
- Docker (for `sam build --use-container` and `sam local`)

## Build & run locally

```bash
sam build --use-container
sam local start-api
```

Then call it (SAM local does not run the JWT authorizer, so no token is needed locally):

```bash
curl "http://127.0.0.1:3000/v1/geocode?streetAddress=1600%20Pennsylvania%20Ave%20NW&municipality=Washington&state=DC&zipcode=20500"

curl -X POST http://127.0.0.1:3000/v1/geocode \
  -H 'Content-Type: application/json' \
  -d '{"streetAddress":"208 Anderson St","city":"Hackensack","state":"New Jersey","zipCode":"07601"}'
```

> If `sam local` fails with an SSO/credentials error, prepend dummy credentials —
> the handler needs no AWS creds:
> `env -u AWS_PROFILE AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 sam local start-api`

You can also invoke the function directly with a sample event:

```bash
sam local invoke GeocoderFunction --event events/event.json        # GET individual params
sam local invoke GeocoderFunction --event events/event-post.json   # POST JSON body
```

### Postman

Import `postman/geocoder-sam.postman_collection.json`, then set the `baseUrl` collection
variable (e.g. `http://127.0.0.1:3000` for local) and `jwt` (a token from
resourceQuerier's `POST /api/v1/login`; can be blank locally since `sam local` doesn't
run the authorizer).

### Getting a test token

`scripts/get-token.sh` fetches a JWT from resourceQuerier's login endpoint. It reads
credentials from environment variables (never hardcoded) — set them in your gitignored
`.envrc` (copy `.envrc.example`) and run `direnv allow`:

```bash
export RQ_LOGIN_EMAIL=you@example.com
export RQ_LOGIN_PASSWORD=your-password
# optional: export RQ_API_BASE_URL=https://<resourceQuerier-api>/Prod
```

```bash
./scripts/get-token.sh          # prints the token — e.g. TOKEN=$(./scripts/get-token.sh)
./scripts/get-token.sh --copy   # copies it to the clipboard (macOS)
```

Paste the result into the Postman collection's `jwt` variable. Tokens last ~24h.

## Deploy

```bash
sam build --use-container
sam deploy --guided
```

After deploying, the `GeocoderApiUrl` stack output gives the invoke URL. The API is
protected by resourceQuerier's JWT authorizer, referenced via the
`/dev/resourceQuerier/authorizer/functionArn` SSM parameter — resourceQuerier must
publish that parameter (deploy) **before** geocoder-sam is deployed. Authenticate by
obtaining a token from resourceQuerier's `POST /api/v1/login` and sending it as
`Authorization: Bearer <jwt>`.

## Unit tests

```bash
bundle install
bundle exec rspec
```

## Cleanup

```bash
sam delete --stack-name geocoder-sam
```
