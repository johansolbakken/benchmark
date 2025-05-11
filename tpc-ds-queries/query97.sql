WITH
  `ssci` AS (
    SELECT
      `ss`.`ss_customer_sk` AS `customer_sk`,
      `ss`.`ss_item_sk`     AS `item_sk`
    FROM `store_sales` AS `ss`
    JOIN `date_dim` AS `d`
      ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    WHERE `d`.`d_month_seq` BETWEEN 1212 AND 1212 + 11
    GROUP BY
      `ss`.`ss_customer_sk`,
      `ss`.`ss_item_sk`
  ),
  `csci` AS (
    SELECT
      `cs`.`cs_bill_customer_sk` AS `customer_sk`,
      `cs`.`cs_item_sk`          AS `item_sk`
    FROM `catalog_sales` AS `cs`
    JOIN `date_dim` AS `d`
      ON `cs`.`cs_sold_date_sk` = `d`.`d_date_sk`
    WHERE `d`.`d_month_seq` BETWEEN 1212 AND 1212 + 11
    GROUP BY
      `cs`.`cs_bill_customer_sk`,
      `cs`.`cs_item_sk`
  )
SELECT
  SUM(CASE WHEN `u`.`store_customer_sk`   IS NOT NULL
            AND `u`.`catalog_customer_sk` IS NULL THEN 1 ELSE 0 END)
    AS `store_only`,
  SUM(CASE WHEN `u`.`store_customer_sk`   IS NULL
            AND `u`.`catalog_customer_sk` IS NOT NULL THEN 1 ELSE 0 END)
    AS `catalog_only`,
  SUM(CASE WHEN `u`.`store_customer_sk`   IS NOT NULL
            AND `u`.`catalog_customer_sk` IS NOT NULL THEN 1 ELSE 0 END)
    AS `store_and_catalog`
FROM (
  SELECT
    `s`.`customer_sk`         AS `store_customer_sk`,
    `s`.`item_sk`             AS `store_item_sk`,
    `c`.`customer_sk`         AS `catalog_customer_sk`,
    `c`.`item_sk`             AS `catalog_item_sk`
  FROM `ssci` AS `s`
  LEFT JOIN `csci` AS `c`
    ON `s`.`customer_sk` = `c`.`customer_sk`
   AND `s`.`item_sk`     = `c`.`item_sk`

  UNION ALL

  SELECT
    `s2`.`customer_sk`,
    `s2`.`item_sk`,
    `c2`.`customer_sk`,
    `c2`.`item_sk`
  FROM `csci` AS `c2`
  LEFT JOIN `ssci` AS `s2`
    ON `s2`.`customer_sk` = `c2`.`customer_sk`
   AND `s2`.`item_sk`     = `c2`.`item_sk`
  WHERE `s2`.`customer_sk` IS NULL
) AS `u`
LIMIT 100;
