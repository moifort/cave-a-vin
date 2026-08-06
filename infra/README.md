# Vinarium — Terraform infrastructure

This module provisions the entire Firebase stack for Vinarium from a
greenfield GCP project: project itself, Firebase enablement, Firestore
(Native), security rules + indexes, Identity Platform with Apple OAuth,
the iOS Firebase app (and downloads `GoogleService-Info.plist`), the
secrets in Secret Manager, and the Cloud Function Gen 2 that runs the
Nitro/GraphQL backend.

## Prerequisites

- `gcloud` CLI authenticated with Application Default Credentials:
  `gcloud auth application-default login`
- `terraform >= 1.6`
- `bun` (used by the `bootstrap.sh` driver to build the Nitro bundle)
- An Apple Developer account with a Service ID and a `.p8` private key
  (Sign in with Apple). See `ios/FIREBASE_SETUP.md` for the exact steps.
- A GCP billing account id and either an `org_id` or `folder_id`.

## One-time bootstrap

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars: project_id, billing, Apple, secrets
cp ~/Downloads/AuthKey_KEY1234567.p8 infra/

# From repo root
make bootstrap
```

The `bootstrap.sh` driver:

1. validates prerequisites,
2. runs `bun install + bun run generate:graphql + bun run build`,
3. runs `terraform init && terraform apply -auto-approve`,
4. POSTs `/admin/migrate` with the generated admin token,
5. prints the Cloud Function URL and the iOS plist path.

End state after a fresh bootstrap: backend operational, Firestore ready,
Apple Sign-In configured, `ios/Vinarium/GoogleService-Info.plist` written.

## The one step Terraform cannot take: Google Analytics

The app measures its activation funnel with Firebase Analytics, which only
reports once the Firebase project is linked to a Google Analytics property.
That link has no Terraform resource
([hashicorp/terraform-provider-google#17450](https://github.com/hashicorp/terraform-provider-google/issues/17450)),
so a fresh bootstrap leaves the SDK emitting into the void until it is made
by hand — once per project, and never again.

The REST call exists
([`projects.addGoogleAnalytics`](https://firebase.google.com/docs/projects/api/reference/rest/v1beta1/projects/addGoogleAnalytics)):

```bash
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: vinarium-prod" \
  -H "Content-Type: application/json" \
  -d '{"analyticsAccountId":"<GA account id>"}' \
  https://firebase.googleapis.com/v1beta1/projects/vinarium-prod:addGoogleAnalytics
```

In practice it answers 403: linking acts on the caller's Analytics account,
which needs the `analytics.edit` scope, and Google refuses that scope to
gcloud's OAuth client ("this app is blocked"). So the link is made in the
Firebase console instead — Project settings → Integrations → Google Analytics
→ Enable — picking the "Default Account for Firebase" account, which creates
a property named after the project and a data stream per registered app.

To check the state of a project, which is what the console does not spell out:

```bash
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: vinarium-prod" \
  https://firebase.googleapis.com/v1beta1/projects/vinarium-prod/analyticsDetails
```

`404` means nothing is linked. Linked, it returns the property and one
`streamMappings` entry per app. `GoogleService-Info.plist` does not change
when the link is made, so no `terraform apply` is needed afterwards.

## Subsequent deploys (CI)

Every push to `main` runs `.github/workflows/deploy.yml`, which builds the
Nitro bundle and runs `terraform apply` against the same state stored in
GCS. Only the function source archive changes between runs, so the diff
is minimal.

## Teardown

```bash
make destroy
```

Removes the Cloud Function, Firestore data, project, and everything else
created by this module. The project will retain billing for ~30 days
after deletion (GCP soft-delete).
