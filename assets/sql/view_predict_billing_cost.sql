with billing_date as
(
  SELECT date FROM UNNEST(
  GENERATE_DATE_ARRAY(
    (SELECT MAX(CAST(usage_start_time AS DATE)+1) FROM `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`),
    (SELECT MAX(CAST(usage_start_time AS DATE)+29) FROM `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`)
    )
  ) date
),
billing_projects as
(
   select distinct project.name as project_name from `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`   
),
current_cost as
(
  select date, project_name, cost from `devrel-solutions-carlos-100.terraform_billing_forecast.VW_CLOUD_BILLING` LIMIT 200
)
select date, project_name, null as cost from billing_date, billing_projects 
union all
select date, project_name, cost from current_cost
;