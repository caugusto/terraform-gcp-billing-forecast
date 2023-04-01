        SELECT
        DATE(usage_start_time) date,
        project.name project_name,
        null as cost
        FROM 
        `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`
         WHERE DATE(usage_start_time) >=
        (SELECT
         DATE_SUB( (
          SELECT
           MAX(DATE(usage_start_time))
          FROM
          `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`), INTERVAL (
           SELECT
            ABS(CAST((DATE_DIFF(MIN(DATE(usage_start_time)), MAX(DATE(usage_start_time)), DAY)) * .10 AS INT64))
           FROM
           `data-analytics-pocs.public.gcp_billing_export_v1_EXAMPL_E0XD3A_DB33F1`) DAY))
           GROUP BY
                 1,
                 2;