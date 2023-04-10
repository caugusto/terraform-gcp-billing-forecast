with billing_date as
(
  SELECT date FROM UNNEST(
    GENERATE_DATE_ARRAY(
      CAST('2018-10-09' AS DATE),
      CAST('2018-10-09' AS DATE)+60
    )
  ) date
),
billing_projects as
(
   select distinct project.name as project_name from `${par_bq_public_billing_data}`   
),
current_cost as
(
  select date, project_name, cost from `${par_project_id}.${par_bq_dataset}.${par_bq_training_view_name}` LIMIT 200
)
select date, project_name, null as cost from billing_date, billing_projects 
union all
select date, project_name, cost from current_cost
;