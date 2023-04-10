# --------------------------------------------------
# VARIABLES
# Set these before applying the configuration
# --------------------------------------------------

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
}

variable "region" {
  type        = string
  description = "Google Cloud Region"
  default     = "us-central1"
}

variable "labels" {
  type        = map(string)
  description = "A map of labels to apply to contained resources."
  default     = { "edw-bigquery" = true }
}

variable "enable_apis" {
  type        = string
  description = "Whether or not to enable underlying apis in this solution. ."
  default     = true
}

variable "force_destroy" {
  type        = string
  description = "Whether or not to protect BigQuery resources from deletion when solution is modified or changed."
  default     = true
}

variable "deletion_protection" {
  type        = string
  description = "Whether or not to protect GCS resources from deletion when solution is modified or changed."
  default     = false
}


variable "bq_public_billing_data" {
  type        = string
  description = "Table in Public BQ Dataset containging billing info"
  default     = "data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1"
}

variable "bq_dataset_name" {
  type        = string
  description = "Dataset with training and billing prediction data"
  default     = "gcpsolution_billingforecast"
}

variable "bq_dataset_location" {
  type        = string
  description = "Dataset location to host training and billing prediction data"
  default     = "US"
}

variable "bq_training_view_name" {
  type        = string
  description = "BQ View for model training"
  default     = "VW_CLOUD_BILLING"
}

variable "bq_prediction_view_name" {
  type        = string
  description = "BQ View for model training"
  default     = "VW_PREDICT_CLOUD_BILLING"
}

variable "bq_looker_view_name" {
  type        = string
  description = "BQ View for Looker Studios Visualization"
  default     = "VW_LOOKER_FORECAST"
}

variable "vertexai_dataset_name" {
  type        = string
  description = "Vertex AI dataset name"
  default     = "gcpsolution_billingforecast_dataset"
}

variable "vertexai_training_name" {
  type        = string
  description = "Vertex AI training job name"
  default     = "gcpsolution_billingforecast_training"
}

variable "vertexai_bq_datasource" {
  type        = string
  description = "Table to be used by Vertex AI training and Vertex AI dataset creation"
  default     = "bq://devrel-solutions-carlos-100.gcpsolution_billingforecast.VW_CLOUD_BILLING"
}

variable "vertexai_prediction_name" {
  type        = string
  description = "Vertex AI batch prediction job name"
  default     = "gcpsolution_billingforecast_batchprediction"
}

variable "vertexai_workflow_name" {
  type        = string
  description = "Vertex AI workflow name"
  default     = "gcpsolution_billingforecast_workflow"
}
