{
    "displayName": "${vertexai_training_name}",
    "trainingTaskDefinition": "gs://google-cloud-aiplatform/schema/trainingjob/definition/automl_forecasting_1.0.0.yaml",
    "trainingTaskInputs": {
        "targetColumn": "cost",
        "timeColumn": "date",
        "timeSeriesIdentifierColumn": "project_name",
        "time_series_attribute_columns": [],
        "available_at_forecast_columns": ["date"],
        "unavailable_at_forecast_columns": ["cost"],
        "trainBudgetMilliNodeHours": 1000,
        "dataGranularity": {"unit": "day", "quantity": 1},
        "forecast_horizon": 30,
        "context_window": 90,
        "optimizationObjective": "minimize-rmse",
        "transformations": [
            {"timestamp":  {"column_name" : "date"} },
            {"numeric":  {"column_name" : "cost"} }
        ]    
    },
    "modelToUpload": {"displayName": "${vertexai_training_name}"},
    "inputDataConfig": {
      "datasetId": "${vertexai_dataset_id}"
    }
}
