{
  "displayName": "${vertexai_prediction_name}",
  "model": "${training_model}",
  "inputConfig": {
    "instancesFormat": "bigquery",
    "bigquerySource": {
      "inputUri": "${vertexai_bq_datasource}"
    }
  },
  "outputConfig": {
    "predictionsFormat": "bigquery",
    "bigqueryDestination": {
      "outputUri": "bq://${out_project_id}.terraform_billing_forecast"
    }
  },
  "generateExplanation": true

}