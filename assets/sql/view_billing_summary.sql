
SELECT
              DATE(usage_start_time) date,
              project.name project_name,
              SUM(cost) AS cost
            FROM 
              `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`
            WHERE DATE(usage_start_time) < CAST('2018-10-09' as DATE)  
            GROUP BY 1,2;