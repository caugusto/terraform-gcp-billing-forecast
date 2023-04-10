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
    "bigquerystorage.googleapis.com",
    "cloudapis.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "workflows.googleapis.com",
    "aiplatform.googleapis.com",
    "ml.googleapis.com"
  ]
}


##### Needs to grant vertexai user role to workflow user


# Endpoin name must be unique for the project
resource "random_id" "random_id" {
  byte_length = 4
}

resource "time_sleep" "wait_after_apis_activate" {
  depends_on      = [module.project-services]
  create_duration = "30s"

}


###### Enable workflows and grant privileges

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

resource "google_project_iam_member" "workflows_sa_bq_resource_mgr" {
  project = module.project-services.project_id
  role    = "roles/bigquery.resourceAdmin"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_bq_data
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

resource "google_project_iam_member" "workflows_sa_bq_read" {
  project = module.project-services.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflow_service_account_token_role
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

resource "google_project_iam_member" "workflows_sa_vertexai_user" {
  project = module.project-services.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"

  depends_on = [
    google_project_iam_member.workflows_sa_log_writer
  ]
}
####### End Workflow service enablement section

resource "time_sleep" "wait_roles_activate" {
  depends_on      = [
  google_project_iam_member.workflows_sa_bq_read,
  google_project_iam_member.workflows_sa_bq_data,
  google_project_iam_member.workflows_sa_bq_resource_mgr,
  google_project_iam_member.workflow_service_account_token_role,
  google_project_iam_member.workflows_sa_log_writer,
  google_project_iam_member.workflows_sa_vertexai_user,
    ]
  create_duration = "60s"
}



resource "google_bigquery_dataset" "create_bq_dataset" {
  dataset_id                  = "${var.bq_dataset_name}"
  friendly_name               = "${var.bq_dataset_name}"
  location                    = "${var.bq_dataset_location}"
  project                     = module.project-services.project_id
  delete_contents_on_destroy  = "${var.force_destroy}"
  depends_on = [
    time_sleep.wait_roles_activate
  ]
}



resource "google_bigquery_table" "create_view_billing_summary" {
  project         = module.project-services.project_id
  dataset_id = google_bigquery_dataset.create_bq_dataset.dataset_id
  table_id   = "${var.bq_training_view_name}"
#  deletion_protection = false
 
  view {
    query = file("${path.module}/assets/sql/view_billing_summary.sql")
    use_legacy_sql = false
  }
  depends_on = [
    google_bigquery_dataset.create_bq_dataset
  ]
  
}

resource "time_sleep" "wait_billing_summary_view" {
  depends_on      = [
    google_bigquery_table.create_view_billing_summary
    ]
  create_duration = "30s"
}


data "template_file" "bq_template_prediction_sql" {
  template = "${file("${path.module}/assets/sql/view_predict_billing_cost.sql")}"
  vars = {
    par_project_id = "${module.project-services.project_id}"
    par_bq_dataset = "${var.bq_dataset_name}"
    par_bq_training_view_name = "${var.bq_training_view_name}"
    par_bq_public_billing_data = "${var.bq_public_billing_data}"
  }
  depends_on = [
    time_sleep.wait_billing_summary_view
  ]
}

resource "google_bigquery_table" "create_view_prediction_summary" {
  project         = module.project-services.project_id
  dataset_id = google_bigquery_dataset.create_bq_dataset.dataset_id
  table_id   = "${var.bq_prediction_view_name}"
#  deletion_protection = false
 
  view {
    query = data.template_file.bq_template_prediction_sql.rendered
    use_legacy_sql = false
  }
  depends_on = [
    google_bigquery_table.create_view_billing_summary,
    time_sleep.wait_billing_summary_view,
    data.template_file.bq_template_prediction_sql
  ]
  
}

resource "google_bigquery_table" "create_view_looker" {
  project         = module.project-services.project_id
  dataset_id = google_bigquery_dataset.create_bq_dataset.dataset_id
  table_id   = "${var.bq_looker_view_name}"
#  deletion_protection = false
 
  view {
    query = file("${path.module}/assets/sql/view_looker_forecast.sql")
    use_legacy_sql = false
  }
  depends_on = [
    google_bigquery_dataset.create_bq_dataset
  ]
  
}



data "template_file" "workflow_template_vertex_ai" {
  template = "${file("${path.module}/assets/yaml/workflow_vertexai_template.yaml")}"
  vars = {
    par_region = "${var.region}"
    par_vertexai_dataset = "${var.vertexai_dataset_name}"
    par_vertexai_training_name = "${var.vertexai_training_name}"
    par_vertexai_prediction_name = "${var.vertexai_prediction_name}"
    par_bq_dataset = "${var.bq_dataset_name}"
    par_bq_looker_view_name = "${var.bq_looker_view_name}"
    par_bq_training_view_name = "${var.bq_training_view_name}"
    par_bq_prediction_view_name = "${var.bq_prediction_view_name}"
  }
  depends_on = [
    google_bigquery_table.create_view_looker,
    time_sleep.wait_roles_activate
  ]
}


resource "google_workflows_workflow" "workflow_template_vertex_ai" {
  name            = "${var.vertexai_workflow_name}"
  project         = module.project-services.project_id
  region          = "${var.region}"
  description     = "Creates VertexAI database, training, batch prediction and Looker Studio view on top of the prediction table"
  service_account = google_service_account.workflows_sa.email
  source_contents = data.template_file.workflow_template_vertex_ai.rendered
   depends_on = [
    data.template_file.workflow_template_vertex_ai,
    time_sleep.wait_roles_activate,
    google_bigquery_table.create_view_prediction_summary,
    google_bigquery_table.create_view_looker,
    google_bigquery_table.create_view_billing_summary
  ]
}




# Execute the workflow

data "google_client_config" "current" {
}
provider "http" {
}


data "http" "call_workflow_template_vertex_ai" {
  url = "https://workflowexecutions.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.workflow_template_vertex_ai.name}/executions"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
   depends_on = [
        google_workflows_workflow.workflow_template_vertex_ai,
        time_sleep.wait_roles_activate

  ]
}


#output "output_call_workflow_template_vertex_ai" {
#  value = data.http.call_workflow_template_vertex_ai.response_body
#}

locals {
  end_msg = "Script completed successfully but VertexAI is still working in the background. Clone https://lookerstudio.google.com/c/reporting/c8a62d54-9a68-44ca-8100-e95b1e19ca80/page/mPzLD and update the datasource for the latest status"
}


output "out_end_msg" {
  value =  local.end_msg
}
