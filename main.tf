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
    "workflows.googleapis.com",
    "aiplatform.googleapis.com"
  ]
}

# Endpoin name must be unique for the project
resource "random_id" "random_id" {
  byte_length = 4
}

resource "time_sleep" "wait_after_apis_activate" {
  depends_on      = [module.project-services]
  create_duration = "30s"

}


resource "google_bigquery_dataset" "create_bq_dataset" {
  dataset_id                  = "${var.bq_dataset_name}"
  friendly_name               = "${var.bq_dataset_name}"
  location                    = "${var.bq_dataset_location}"
  project                     = module.project-services.project_id

  depends_on = [
    time_sleep.wait_after_apis_activate
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


resource "google_bigquery_table" "create_view_prediction_summary" {
  project         = module.project-services.project_id
  dataset_id = google_bigquery_dataset.create_bq_dataset.dataset_id
  table_id   = "${var.bq_prediction_view_name}"
#  deletion_protection = false
 
  view {
    query = file("${path.module}/assets/sql/view_predict_billing_cost.sql")
    use_legacy_sql = false
  }
  depends_on = [
    google_bigquery_dataset.create_bq_dataset
  ]
  
}


data "google_client_config" "current" {
}
provider "http" {
}

data "template_file" "template_create_dataset" {
  template = "${file("${path.module}/assets/tpl/cr_vertexai_dataset.tpl")}"
  vars = {
    vertexai_dataset = "${var.vertexai_dataset_name}"
    #vertexai_bq_datasource = "${var.vertexai_bq_datasource}"
    vertexai_bq_datasource = "bq://${var.project_id}.${var.bq_dataset_name}.${var.bq_training_view_name}"

  }
}

data "http" "create_vertexai_dataset" {
  url = "https://${var.region}-aiplatform.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/datasets"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  #request_body = file("${path.module}/assets/json/request_cr_vertexai_dataset.json")
  request_body = data.template_file.template_create_dataset.rendered

   depends_on = [
        google_bigquery_table.create_view_billing_summary
  ]
  lifecycle {
    postcondition {
      condition     = contains([200, 201, 202], self.status_code)
      error_message = "Status code invalid"
    }
  }
}

output "output_create_vertexai_dataset" {
  value = data.http.create_vertexai_dataset.response_body
}

locals {
  #dataset_id = replace(jsondecode(data.http.create_vertexai_dataset.response_body).name,"//operations/.*/","")
  local_dataset_id = replace(replace(jsondecode(data.http.create_vertexai_dataset.response_body).name,"//operations/.*/",""),"/projects.*datasets//","")
  vertex_crdataset_operation_id        = jsondecode(data.http.create_vertexai_dataset.response_body).name 

}

output "out_local_dataset_id" {
  value =  local.local_dataset_id
}

output "out_local_operation_id" {
  value =  local.vertex_crdataset_operation_id
}

resource "time_sleep" "wait_vertexai_dataset_creation" {
  create_duration = "30s"
  depends_on      = [
    data.http.create_vertexai_dataset
    ]
}

# Submitting the Vertex AI training job 

data "template_file" "template_create_training" {
  template = "${file("${path.module}/assets/tpl/cr_vertexai_training_pipeline.tpl")}"
  vars = {
    vertexai_dataset_id = "${local.local_dataset_id}"
    vertexai_training_name = "${var.vertexai_training_name}"

  }
}

data "http" "create_vertexai_training" {
  url = "https://${var.region}-aiplatform.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/trainingPipelines"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  request_body = data.template_file.template_create_training.rendered

   depends_on = [
        data.http.create_vertexai_dataset,
        time_sleep.wait_vertexai_dataset_creation
  ]

#  lifecycle {
#    postcondition {
#      condition     = contains([200, 201, 202], self.status_code)
#      error_message = "Status code invalid"
#    }
#  }
}

output "output_create_vertexai_training" {
  value = data.http.create_vertexai_training.response_body

  depends_on = [
    data.http.create_vertexai_training
  ]
}

locals {
  local_trainingpipeline_id = jsondecode(data.http.create_vertexai_training.response_body).name 
}
output "out_local_trainingpipeline_id" {
  value =  local.local_trainingpipeline_id
}

resource "time_sleep" "wait_vertexai_training_creation1" {
  # 2 hours and 10 minutes wait
  create_duration = "130m"
  depends_on      = [
    data.http.create_vertexai_training
    ]
}


data "http" "getstatus_vertexai_training" {
  url = "https://${var.region}-aiplatform.googleapis.com/v1/${local.local_trainingpipeline_id}"
  #url="https://us-central1-aiplatform.googleapis.com/v1/projects/devrel-solutions-carlos-100/locations/us-central1/trainingPipelines/7514546661654265856"
  method = "GET"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }

   depends_on = [
        time_sleep.wait_vertexai_training_creation1
  ]

#  lifecycle {
#    postcondition {
#      condition     = contains([200, 201, 202], self.status_code)
#      error_message = "Status code invalid"
#    }
#  }
}

output "output_getstatus_vertexai_training" {
  value = data.http.getstatus_vertexai_training.response_body
} 


locals {
  local_trainingmodel_id = jsondecode(data.http.getstatus_vertexai_training.response_body).modelToUpload.name
  local_training_state = jsondecode(data.http.getstatus_vertexai_training.response_body).state 

}

output "out_local_trainingmodel_id" {
  value =  local.local_trainingmodel_id
}

output "out_local_trainingmodel_state" {
  value =  local.local_training_state
}


# Submitting the Vertex AI batch prediction 

data "template_file" "template_create_batch_prediction" {
  template = "${file("${path.module}/assets/tpl/cr_vertexai_batch_prediction.tpl")}"
  vars = {
    #vertexai_bq_datasource = "${var.vertexai_bq_datasource}"
    vertexai_bq_datasource = "bq://${var.project_id}.${var.bq_dataset_name}.${var.bq_prediction_view_name}"
    vertexai_prediction_name = "${var.vertexai_prediction_name}"
    out_project_id = "${var.project_id}"
    training_model = "${local.local_trainingmodel_id}"
  }
}

data "http" "create_vertexai_prediction" {
  url = "https://${var.region}-aiplatform.googleapis.com/v1/projects/${module.project-services.project_id}/locations/${var.region}/batchPredictionJobs"
  method = "POST"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  request_body = data.template_file.template_create_batch_prediction.rendered

   depends_on = [
        data.http.getstatus_vertexai_training
  ]

#  lifecycle {
#    postcondition {
#      condition     = contains([200, 201, 202], self.status_code)
#      error_message = "Status code invalid"
#    }
#  }
}

output "output_create_vertexai_prediction" {
  value = data.http.create_vertexai_prediction.response_body

  depends_on = [
    data.http.create_vertexai_prediction
  ]
}


resource "time_sleep" "wait_vertexai_prediction_creation" {
  # Wait for 1 hour
  create_duration = "40m"
  depends_on      = [
    data.http.create_vertexai_prediction
    ]
}

locals {
  local_prediction_id = jsondecode(data.http.create_vertexai_prediction.response_body).name 
}
output "out_local_prediction_id" {
  value =  local.local_prediction_id
}



# Get Status of Batch Prediction submission

data "http" "getstatus_vertexai_prediction" {
  url = "https://${var.region}-aiplatform.googleapis.com/v1/${local.local_prediction_id}"
  #url="https://us-central1-aiplatform.googleapis.com/v1/projects/devrel-solutions-carlos-100/locations/us-central1/trainingPipelines/616764862848040960"
  method = "GET"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }

   depends_on = [
        time_sleep.wait_vertexai_prediction_creation
  ]

#  lifecycle {
#    postcondition {
#      condition     = contains([200, 201, 202], self.status_code)
#      error_message = "Status code invalid"
#    }
#  }
}


output "output_getstatus_vertexai_prediction" {
  value = data.http.getstatus_vertexai_prediction.response_body

  depends_on = [
    data.http.getstatus_vertexai_prediction
  ]
}



