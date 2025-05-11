WITH
  `daily_web` AS (
    SELECT
      `ws`.`ws_item_sk`   AS `item_sk`,
      `d`.`d_date`        AS `d_date`,
      SUM(`ws`.`ws_sales_price`) AS `daily_sales`
    FROM `web_sales` AS `ws`
    JOIN `date_dim` AS `d`
      ON `ws`.`ws_sold_date_sk` = `d`.`d_date_sk`
    WHERE `ws`.`ws_item_sk` IS NOT NULL
      AND `d`.`d_month_seq` BETWEEN 1212 AND 1212 + 11
    GROUP BY `ws`.`ws_item_sk`, `d`.`d_date`
  ),
  `web_v1` AS (
    SELECT
      `item_sk`,
      `d_date`,
      SUM(`daily_sales`) OVER (
        PARTITION BY `item_sk`
        ORDER BY `d_date`
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS `cume_sales`
    FROM `daily_web`
  ),
  `daily_store` AS (
    SELECT
      `ss`.`ss_item_sk`   AS `item_sk`,
      `d`.`d_date`        AS `d_date`,
      SUM(`ss`.`ss_sales_price`) AS `daily_sales`
    FROM `store_sales` AS `ss`
    JOIN `date_dim` AS `d`
      ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    WHERE `ss`.`ss_item_sk` IS NOT NULL
      AND `d`.`d_month_seq` BETWEEN 1212 AND 1212 + 11
    GROUP BY `ss`.`ss_item_sk`, `d`.`d_date`
  ),
  `store_v1` AS (
    SELECT
      `item_sk`,
      `d_date`,
      SUM(`daily_sales`) OVER (
        PARTITION BY `item_sk`
        ORDER BY `d_date`
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS `cume_sales`
    FROM `daily_store`
  ),
  `combined` AS (
    SELECT
      COALESCE(`web`.`item_sk`, `store`.`item_sk`) AS `item_sk`,
      COALESCE(`web`.`d_date`, `store`.`d_date`) AS `d_date`,
      `web`.`cume_sales`   AS `web_sales`,
      `store`.`cume_sales` AS `store_sales`
    FROM `web_v1` AS `web`
    LEFT JOIN `store_v1` AS `store`
      ON `web`.`item_sk` = `store`.`item_sk`
     AND `web`.`d_date` = `store`.`d_date`
    UNION ALL
    SELECT
      COALESCE(`web`.`item_sk`, `store`.`item_sk`),
      COALESCE(`web`.`d_date`, `store`.`d_date`),
      `web`.`cume_sales`,
      `store`.`cume_sales`
    FROM `web_v1` AS `web`
    RIGHT JOIN `store_v1` AS `store`
      ON `web`.`item_sk` = `store`.`item_sk`
     AND `web`.`d_date` = `store`.`d_date`
    WHERE `web`.`item_sk` IS NULL
  ),
  `ranked` AS (
    SELECT
      `item_sk`,
      `d_date`,
      `web_sales`,
      `store_sales`,
      MAX(`web_sales`) OVER (
        PARTITION BY `item_sk`
        ORDER BY `d_date`
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS `web_cumulative`,
      MAX(`store_sales`) OVER (
        PARTITION BY `item_sk`
        ORDER BY `d_date`
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS `store_cumulative`
    FROM `combined`
  )
SELECT
  `item_sk`,
  `d_date`,
  `web_sales`,
  `store_sales`,
  `web_cumulative`,
  `store_cumulative`
FROM `ranked`
WHERE `web_cumulative` > `store_cumulative`
ORDER BY
  `item_sk`,
  `d_date`
LIMIT 100;
