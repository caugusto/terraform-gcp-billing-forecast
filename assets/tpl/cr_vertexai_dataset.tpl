{
    "display_name": "${vertexai_dataset}",
    "metadata_schema_uri": "gs://google-cloud-aiplatform/schema/dataset/metadata/time_series_1.0.0.yaml",
    "metadata": {
      "input_config": {
        "bigquery_source" :{
          "uri": "${vertexai_bq_datasource}"
        }
      }
    }
  }