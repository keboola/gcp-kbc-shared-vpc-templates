## Prepare backend on Google Cloud Platform
1. Install [Google Cloud client](https://cloud.google.com/sdk/docs/install-sdk) (e.g. via [Brew](https://formulae.brew.sh/cask/google-cloud-sdk#default) on Mac), initialize it by running `gcloud init` and log in to [generate default credentials](https://cloud.google.com/docs/authentication/application-default-credentials#personal) by runing command `gcloud auth application-default login`
2. To prepare the  backend use Terraform template. Make sure you have `resourcemanager.folders.create` permission for the organization.
3. Install [Terraform](https://www.terraform.io/) and use following template
4. Copy terraform template to new directory and name file as [main.tf](https://gist.github.com/romanbracinik/96f8c07140ce605ba336e395f96d24e8#file-main-tf)
5. Go to the new folder with `main.tf` file and run
```
terraform init
```
7. Create a new folder in your organization and use the `folder_id` in the following command.
6. Then run

```
terraform apply \
  -var folder_id=[folder_id] \
  -var billing_account_id=[billing_id] \
  -var backend_prefix=<your prefix, eg. rb-backend>
```
- `billing_id`: Id of billing account to which you wish to add projects created as backend for keboola connection. For more
  information what is billing account please visit [link](https://cloud.google.com/billing/docs/how-to/manage-billing-account).
- `backend_prefix`: prefix to be given to the folder and the main backend project. It is used to differentiate between existing projects and the new backend, or multiple backends in one organization due to the strictness of gcp and project names. The length of the project name is small for GCP, so choose something short e.g. initials rb

When terraform apply ends go to the service project in folder created by Terraform.
1. Go to the newly created service project, the project id is listed at the end of the terraform call. (`service_project_id`). Typically (https://console.cloud.google.com/welcome?project=<service_project_id>)
2. Click on **IAM & Admin**
3. On left panel choose **Service Accounts**
4. Click on email of service account (there is only one, something like js-bq-driver-main-service-acc@js-bq-driver-bq-driver.iam.gserviceaccount.com), and copy email to clipboard, you'll need it for step 9.
5. On to the top choose **Keys** and **Add Key => Create new key**
6. Select Key type JSON
7. Click on the Create button and the file will be automatically downloaded

## Register backend, file storage and create project in Keboola Connection
Most of these parts are done by Keboola.

### Register new file storage - You need to have super admin privileges
```
* Keboola does this
```
- call api endpoint [Keboola Connection Management API · Apiary](https://keboolamanagementapi.docs.apiary.io/#reference/super-file-storage-management/google-cloud-storage-file-storage-collection/create-new-google-cloud-storage) to register new file storage with credentials from downloaded json key file from step 7.  The `filesBucket` (`file_storage_bucket_id`) value is obtained with the output of the terraform call. Fill the matching fields from the json file into the `gcsCredentials` part of the call api. Since the last update GCP has added `universe_domain` to the json key, please do not fill this field.<img width="1296" alt="API request to register File Storage" src="https://user-images.githubusercontent.com/6448364/238565526-178c0236-cf5d-4289-bcde-2d808c7d82f7.png">
- note the id of the new file storage that is returned to us in the response (`id_of_new_file_storage`)
- choose the region according to which stack you will register it on
    - `us-east-1` - https://connection.keboola.com/
    - `eu-central-1` - https://connection.eu-central-1.keboola.com/
      <img width="707" alt="API response after File Storage registration" src="https://user-images.githubusercontent.com/6448364/238565747-ce8b4919-d119-4d65-bb10-35843911722d.png">


### Register new storage backend
```
* Keboola does this usually, but there’s an option to register backend by client
```
- call api endpoint [Keboola Connection Management API · Apiary](https://keboolamanagementapi.docs.apiary.io/#reference/super-storage-backends-management/bigquery-storage-backend-collection/create-a-new-bigquery-backend)  to register new Bigquery storage backend with credentials from downloaded json key file from step 7. The `folderId` (only number after `/`) value is obtained with the output of the terraform call. Fill the matching fields from the json file into the `credentials` part of the call api. Since the last update GCP has added universe_domain to the json key, please do not fill this field.
- credentials are inserted as in the previous step when registering file storage
- note the id of the new storage backend that is returned to us in the response (`id_of_new_storage_backend`)
  <img width="733" alt="API response after Storage Backend registration" src="https://user-images.githubusercontent.com/6448364/238566165-929ec2ce-fbaf-4ba0-a50e-03893038c0d3.png">

### Create new project and assign new file storage and storage backend to it

```
* Keboola does this
```

- create new project using api call on desired stack
- fill `organization_id`

```
curl --include \
     --request POST \
     --header "Content-Type: application/json" \
     --header "X-KBC-ManageApiToken: your_token" \
     --data-binary "{
  \"name\": \"My Test Bq project\",
  \"type\": \"production\",
  \"defaultBackend\": \"bigquery\",
  \"dataRetentionTimeInDays\": \"1\"
}" \
'https://connection.keboola.com/manage/organizations/organization_id/projects'
```
- note the id of the new project from the response (`id_of_your_new_project`)
- assign own new file storage to new project

```
curl --include \
     --request POST \
     --header "Content-Type: application/json" \
     --header "X-KBC-ManageApiToken: your_token" \
     --data-binary "{
  \"fileStorageId\": \"id_of_new_file_storage\"
}" \
'https://connection.keboola.com/manage/projects/id_of_your_new_project/file-storage'
```
- assign own new big query storage backend to new project
```
curl --include \
     --request POST \
     --header "Content-Type: application/json" \
     --header "X-KBC-ManageApiToken: your_token" \
     --data-binary "{
  \"storageBackendId\": \"id_of_new_storage_backend\"
}" \
'https://connection.keboola.com/manage/projects/id_of_your_new_project/storage-backend'
```
You should now be able to start using the new project with the Bigquery backend.

 