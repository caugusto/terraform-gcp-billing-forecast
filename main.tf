data "google_project" "project" {
  project_id = var.project_id
}

module "project-services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "13.0.0"
  disable_services_on_destroy = false

  project_id  = var.project_id
  enable_apis = true

  activate_apis = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "bigquerymigration.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "bigquerystorage.googleapis.com",
    "cloudapis.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "datacatalog.googleapis.com",
    "datalineage.googleapis.com",
    "dataplex.googleapis.com",
    "dataproc.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "storage-api.googleapis.com",
    "storage.googleapis.com",
    "workflows.googleapis.com"
  ]
}

resource "time_sleep" "wait_after_apis_activate" {
  depends_on      = [module.project-services]
  create_duration = "30s"
}

# Set up BigQuery resources
# # Create the BigQuery dataset
resource "google_bigquery_dataset" "gcp_lakehouse_ds" {
  project       = module.project-services.project_id
  dataset_id    = "gcp_lakehouse_ds"
  friendly_name = "My gcp_lakehouse Dataset"
  description   = "My gcp_lakehouse Dataset with tables"
  location      = var.region
  labels        = var.labels
}



# # Create a BigQuery connection
resource "google_bigquery_connection" "gcp_lakehouse_connection" {
  project       = module.project-services.project_id
  connection_id = "gcp_lakehouse_connection"
  location      = var.region
  friendly_name = "gcp lakehouse storage bucket connection"
  cloud_resource {}
}



## This grants permissions to the service account of the connection created in the last step.
resource "google_project_iam_member" "connectionPermissionGrant" {
  project = module.project-services.project_id
  role    = "roles/storage.objectViewer"
  member  = format("serviceAccount:%s", google_bigquery_connection.gcp_lakehouse_connection.cloud_resource[0].service_account_id)
}

#resource "google_bigquery_routine" "create_view_ecommerce" {
#  project         = module.project-services.project_id
#  dataset_id      = google_bigquery_dataset.gcp_lakehouse_ds.dataset_id
#  routine_id      = "create_view_ecommerce"
#  routine_type    = "PROCEDURE"
#  language        = "SQL"
#  definition_body = file("${path.module}/assets/sql/view_ecommerce.sql")
#}


resource "google_storage_bucket" "destination_bucket" {
  name                        = "gcp-lakehouse-edw-export-${module.project-services.project_id}"
  project                     = module.project-services.project_id
  location                    = "us-central1"
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

}





resource "google_project_service_identity" "workflows" {
  provider   = google-beta
  project    = module.project-services.project_id
  service    = "workflows.googleapis.com"
  depends_on = [time_sleep.wait_after_apis_activate]
}
resource "google_service_account" "workflows_sa" {
  project      = module.project-services.project_id
  account_id   = "workflows-sa"
  display_name = "Workflows Service Account"
  depends_on   = [google_project_service_identity.workflows]
}

# Grant the Workflow service account Workflows Admin
resource "google_project_iam_member" "workflow_service_account_invoke_role" {
  project = module.project-services.project_id
  role    = "roles/workflows.admin"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
  depends_on   = [google_service_account.workflows_sa]
}

resource "google_project_iam_member" "workflows_sa_bq_data" {
  project = module.project-services.project_id
  role    = "roles/bigquery.dataOwner"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflow_service_account_invoke_role
  ]
}
resource "google_project_iam_member" "workflows_sa_gcs_admin" {
  project = module.project-services.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_bq_data
  ]
}
resource "google_project_iam_member" "workflows_sa_bq_resource_mgr" {
  project = module.project-services.project_id
  role    = "roles/bigquery.resourceAdmin"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_gcs_admin
  ]
}
resource "google_project_iam_member" "workflow_service_account_token_role" {
  project = module.project-services.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_bq_resource_mgr
  ]
}

#give workflows_sa bq data access 
resource "google_project_iam_member" "workflows_sa_bq_connection" {
  project = module.project-services.project_id
  role    = "roles/bigquery.connectionAdmin"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflow_service_account_token_role
  ]
}
resource "google_project_iam_member" "workflows_sa_bq_read" {
  project = module.project-services.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_bq_connection
  ]
}
resource "google_project_iam_member" "workflows_sa_log_writer" {
  project = module.project-services.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_bq_read
  ]
}

resource "time_sleep" "wait_roles_activate" {
  depends_on      = [
  google_project_iam_member.workflows_sa_bq_read,
  google_project_iam_member.workflows_sa_bq_data,
  google_project_iam_member.workflows_sa_gcs_admin,
  google_project_iam_member.workflows_sa_bq_resource_mgr,
  google_project_iam_member.workflow_service_account_token_role,
  google_project_iam_member.workflows_sa_bq_connection,
  google_project_iam_member.workflows_sa_log_writer,
    ]
  create_duration = "30s"
}


output "workflow_return_bucket_copy" {
  value = data.http.call_workflows_bucket_copy_run.response_body
}

#resource "time_sleep" "wait_after_all_resources" {
#  create_duration = "30s"
#  depends_on = [
#    module.project-services,
#    google_storage_bucket.provisioning_bucket,
#    google_storage_bucket.destination_bucket,
#  ]  
#}

resource "google_workflows_workflow" "workflow_bucket_copy" {
  name            = "workflow_bucket_copy"
  project         = module.project-services.project_id
  region          = "us-central1"
  description     = "Copy data files from public bucket to solution project"
  service_account = google_service_account.workflows_sa.email
  source_contents = file("${path.module}/assets/yaml/bucket_copy.yaml")
   depends_on = [
  google_project_iam_member.workflow_service_account_invoke_role,
  google_project_iam_member.workflows_sa_bq_read,
  google_project_iam_member.workflows_sa_bq_data,
  google_project_iam_member.workflows_sa_gcs_admin,
  google_project_iam_member.workflows_sa_bq_resource_mgr,
  google_project_iam_member.workflow_service_account_token_role,
  google_project_iam_member.workflows_sa_bq_connection,
  google_project_iam_member.workflows_sa_log_writer,
  time_sleep.wait_roles_activate
  ]
}

resource "google_workflows_workflow" "workflows_create_gcp_biglake_tables" {
  name            = "workflow-create-gcp-biglake-tables"
  project         = module.project-services.project_id
  region          = "us-central1"
  description     = "create gcp biglake tables_18"
  service_account = google_service_account.workflows_sa.email
  source_contents = templatefile("${path.module}/assets/yaml/workflow_create_gcp_lakehouse_tables.yaml", {})
  depends_on = [
  google_project_iam_member.workflow_service_account_invoke_role,
  google_project_iam_member.workflows_sa_bq_read,
  google_project_iam_member.workflows_sa_bq_data,
  google_project_iam_member.workflows_sa_gcs_admin,
  google_project_iam_member.workflows_sa_bq_resource_mgr,
  google_project_iam_member.workflow_service_account_token_role,
  google_project_iam_member.workflows_sa_bq_connection,
  google_project_iam_member.workflows_sa_log_writer,
  time_sleep.wait_roles_activate,
  ]

}

#execute workflows
data "google_client_config" "current" {
}
provider "http" {
}

data "http" "call_workflows_bucket_copy_run" {
  url = "https://workflowexecutions.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.workflow_bucket_copy.name}/executions"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
   depends_on = [
        google_workflows_workflow.workflow_bucket_copy

  ]
}

resource "time_sleep" "wait_after_workflow_bucket_copy" {
  create_duration = "15s"
  depends_on = [
    data.http.call_workflows_bucket_copy_run
  ]  
}

data "http" "call_workflows_create_gcp_biglake_tables" {
  url = "https://workflowexecutions.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.workflows_create_gcp_biglake_tables.name}/executions"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
   depends_on = [
        time_sleep.wait_after_workflow_bucket_copy,
  ]
}