# --------------------------------------------------
# VARIABLES
# Set these before applying the configuration
# --------------------------------------------------

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
}

variable "bucket_name" {
  type        = string
  description = "Bucket where source data is stored"
  default     = "data-analytics-demos"
}
variable "region" {
  type        = string
  description = "Google Cloud Region"
  default     = "us-central1"
}

variable "dataset_id" {
  type        = string
  description = "Google Cloud BQ Dataset ID"
  default     = "gcp"
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

variable "use_case_short" {
  type        = string
  description = "Short name for use case"
  default     = "lakehouse"
}

variable "public_data_bucket" {
  type        = string
  description = "Public Data bucket for access"
  default     = "data-analytics-demos"
}

variable "bq_public_billing_data" {
  type        = string
  description = "Table in Public BQ Dataset containging billing info"
  default     = "data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1"
}

variable "bq_dataset_name" {
  type        = string
  description = "Dataset with training and billing prediction data"
  default     = "terraform_billing_forecast"
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

variable "vertexai_dataset_name" {
  type        = string
  description = "Vertex AI dataset name"
  default     = "terraform_dataset"
}

variable "vertexai_training_name" {
  type        = string
  description = "Vertex AI training job name"
  default     = "terraform_training"
}

variable "vertexai_bq_datasource" {
  type        = string
  description = "Table to be used by Vertex AI training and Vertex AI dataset creation"
  default     = "bq://devrel-solutions-carlos-100.terraform_billing_forecast.VW_CLOUD_BILLING"
}

variable "vertexai_prediction_name" {
  type        = string
  description = "Vertex AI batch prediction job name"
  default     = "terraform_batch_prediction"
}
