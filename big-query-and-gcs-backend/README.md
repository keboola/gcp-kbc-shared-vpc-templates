# Prepare backend on Google Cloud Platform

## Prerequisites

- [Google Cloud client](https://cloud.google.com/sdk/docs/install-sdk) (e.g. via [Brew](https://formulae.brew.sh/cask/google-cloud-sdk#default) on macOS), initialize it by running `gcloud init`, and log in to [generate default credentials](https://cloud.google.com/docs/authentication/application-default-credentials#personal) by running command `gcloud auth application-default login`
- [Terraform](https://www.terraform.io/)
- `resourcemanager.folders.create` permission for the organization.
- *Keboola Connection* super admin privileges and token

## Prepare backend

1. Copy Terraform template to a separate directory, and name file as `main.tf`
2. Go to the new directory with `main.tf` file and run:

        terraform init

3. Create a new folder in your organization through GCP Console, and note the ID of the folder for the next step, e.g. `GCP_FOLDER_ID=380380380380`.
4. Set two additional arguments:
    - `GCP_BILLING_ID`: ID of billing account to which you wish to add projects created as backend for *Keboola Connection*. For more
      information what is billing account, please visit [this link](https://cloud.google.com/billing/docs/how-to/manage-billing-account).
    - `BACKEND_PREFIX`: Prefix to be given to the folder and the main backend project. It is used to differentiate between existing projects and the new backend, or multiple backends in one organization due to the strictness of GCP and project names. The length of the project name is short for GCP, so choose something like initials, i.e. `rb`
    - `GCP_REGION`: Location of GCS File Storage bucket. You can choose single region (e.g. `europe-west3`) or multi-region (e.g. `us`). See available [locations](https://cloud.google.com/storage/docs/locations#available-locations)
5. Run:

        terraform apply \
          -var folder_id=$GCP_FOLDER_ID \
          -var billing_account_id=$GCP_BILLING_ID \
          -var backend_prefix=$BACKEND_PREFIX \
          -var gcp_region=$GCP_REGION

You'll get two outputs from after applying the Terraform:

- `service_project_id` - ID of the project that will be used as a backend for *Keboola Connection*
- `file_storage_bucket_id` - ID of the bucket that will be used as a file storage for *Keboola Connection*, set it as `FILE_STORAGE_BUCKET_ID` variable in your shell

After successful Terraform apply:

1. Go to the newly created service project, the project ID is listed at the end of the Terraform call. (`service_project_id`). Typically (`https://console.cloud.google.com/welcome?project=<service_project_id>`)
2. Click on **IAM & Admin**
3. On left panel choose **Service Accounts**
4. Click on email of service account (there is only one, something like `js-bq-driver-main-service-acc@js-bq-driver-bq-driver.iam.gserviceaccount.com`), and copy email to clipboard - you'll need it for step #9.
5. On to the top choose **Keys** and **Add Key => Create new key**
6. Select *JSON* as a key type
7. Click on the *Create* button and the file will be automatically downloaded

## Register backend, file storage and create project in Keboola Connection

Most of these parts are done by Keboola.

### Register new file storage

> [!IMPORTANT]
> Keboola does this
>
> **You need to have super admin privileges**

Call API endpoint [Keboola Connection Management API · Apiary](https://keboolamanagementapi.docs.apiary.io/#reference/super-file-storage-management/google-cloud-storage-file-storage-collection/create-new-google-cloud-storage) to register new file storage with credentials from downloaded JSON key file from step #7.

The `filesBucket` (`$FILE_STORAGE_BUCKET_ID`) value is obtained from the output of the Terraform call in init phase. Fill the matching fields from the JSON file into the `gcsCredentials` part of the API call.

Since the last update GCP has added `universe_domain` to the JSON key - please do not fill this field.

Choose the `$BACKEND_REGION` according to a GCP region you have chosen for the backend earlier e.q. `europe-west3`.

```shell
KBC_MANAGE_API_TOKEN=<your_manage_api_token, "9-faketoken1234567890">
FILE_STORAGE_BUCKET_ID=<file_storage_bucket_id from Terraform apply, e.g. "rb-files-bq-driver">
BACKEND_REGION=<your_backend_region, e.g. "us-central1">
KBC_URL=<your_keboola_connection_url, e.g. "https://connection.keboola.foo.bar">
```

```shell
  curl --include \
        --request POST \
        --header "Content-Type: application/json" \
        --header "X-KBC-ManageApiToken: $KBC_MANAGE_API_TOKEN" \
        --data-binary "{
    \"gcsCredentials\": {
      \"type\": \"service_account\",
      \"project_id\": \"123456789\",
      \"private_key_id\": \"xxx\",
      \"private_key\": \"-----BEGIN PRIVATE KEY-----<key contents>-----END PRIVATE KEY-----\\n\",
      \"client_email\": \"something@else.iam.gserviceaccount.com\",
      \"client_id\": \"123456789\",
      \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\",
      \"token_uri\": \"https://oauth2.googleapis.com/token\",
      \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\",
      \"client_x509_cert_url\": \"https://www.googleapis.com/robot/v1/metadata/x509/something\"
    },
    \"filesBucket\": \"$FILE_STORAGE_BUCKET_ID\",
    \"owner\": \"keboola\",
    \"region\": \"$BACKEND_REGION\"
  }" \
  "$KBC_URL/manage/file-storage-gcs"
```

Note the ID number of the new file storage that is returned in the response (`$NEW_FILE_STORAGE_ID`)

```shell
...
{
  "id": 1, # $NEW_FILE_STORAGE_ID
  "gcsCredentials": {
    "type": "service_account",
...
```

### Register new storage backend

> [!IMPORTANT]
> Keboola does this usually, but there’s an option to register backend by client

Call API endpoint [Keboola Connection Management API · Apiary](https://keboolamanagementapi.docs.apiary.io/#reference/super-storage-backends-management/bigquery-storage-backend-collection/create-a-new-bigquery-backend) to register new BigQuery storage backend with credentials from downloaded JSON key file from step #7.

The `folderId` (only number after `/`) value is obtained with the output of the Terraform call or from GCP Console. Fill the matching fields from the JSON file into the `credentials` part of the API call.

Since the last update GCP has added `universe_domain` to the JSON key - please do not fill this field.

Credentials are inserted as in the previous step when registering file storage

```shell
BQ_FOLDER_ID=<folder_id of your new GCP BigQuery folder, e.g. "123456789">
```

```shell
curl --include \
      --request POST \
      --header "Content-Type: application/json" \
      --header "X-KBC-ManageApiToken: $KBC_MANAGE_API_TOKEN" \
      --data-binary "{
  \"credentials\": {
    \"type\": \"service_account\",
    \"project_id\": \"123456789\",
    \"private_key_id\": \"xxx\",
    \"private_key\": \"-----BEGIN PRIVATE KEY-----<key contents>-----END PRIVATE KEY-----\\n\",
    \"client_email\": \"something@else.iam.gserviceaccount.com\",
    \"client_id\": \"123456789\",
    \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\",
    \"token_uri\": \"https://oauth2.googleapis.com/token\",
    \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\",
    \"client_x509_cert_url\": \"https://www.googleapis.com/robot/v1/metadata/x509/something\"
  },
  \"folderId\": \"$BQ_FOLDER_ID\",
  \"owner\": \"keboola\",
  \"region\": \"$BACKEND_REGION\"
}" \
"$KBC_URL/manage/storage-backend/bigquery"
```

Note the ID of the new storage backend that is returned in the response (`$NEW_STORAGE_BACKEND_ID`)

```shell
...
{
  "id": 6, # $NEW_STORAGE_BACKEND_ID
  "backend": "bigquery",
  "region":"us-central1",
...
```

### Create new project, and assign new file storage and storage backend to it

> [!IMPORTANT]
> Keboola does this

#### Assign new file storage and storage backend to organization

Find your organization's maintaner ID in *Keboola Connection*, e.g. `KBC_MAINTAINER_ID=1`.

This will assign backend and file storage to the Maintainer, so all projects in the organization will be able to use it.

```shell
curl --include \
    --request PATCH \
    --header "Content-Type: application/json" \
    --header "X-KBC-ManageApiToken: $KBC_MANAGE_API_TOKEN" \
    --data-binary "{
      \"defaultConnectionBigqueryId\": \"$NEW_STORAGE_BACKEND_ID\",
      \"defaultFileStorageId\": \"$NEW_FILE_STORAGE_ID\"
}" \
"$KBC_URL/manage/maintainers/$KBC_MAINTAINER_ID"
```

#### Create new project on desired stack

Set `$KBC_ORGANIZATION_ID` to organization ID in *Keboola Connection* you want to create project in, e.g. `KBC_ORGANIZATION_ID=1`.

Note the ID of the new project from the response for the next step, e.g. `NEW_PROJECT_ID=7`.

```shell
curl --include \
      --request POST \
      --header "Content-Type: application/json" \
      --header "X-KBC-ManageApiToken: $KBC_MANAGE_API_TOKEN" \
      --data-binary "{
  \"name\": \"My BQ test project\",
  \"type\": \"production\",
  \"defaultBackend\": \"bigquery\",
  \"dataRetentionTimeInDays\": \"1\"
}" \
"$KBC_URL/manage/organizations/$KBC_ORGANIZATION_ID/projects"
```

#### Assign new file storage to new project

```shell
curl --include \
      --request POST \
      --header "Content-Type: application/json" \
      --header "X-KBC-ManageApiToken: $KBC_MANAGE_API_TOKEN" \
      --data-binary "{
  \"fileStorageId\": \"$NEW_FILE_STORAGE_ID\"
}" \
"$KBC_URL/manage/projects/$NEW_PROJECT_ID/file-storage"
```

🎉 You should now be able to start using the new project with the BigQuery backend.
