
SELECT
              DATE(usage_start_time) date,
              project.name project_name,
              SUM(cost) AS cost
            FROM 
              `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`
            GROUP BY 1,2;