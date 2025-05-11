WITH
  `my_customers` AS (
    SELECT DISTINCT
      `cs_or_ws_sales`.`customer_sk`    AS `c_customer_sk`,
      `c`.`c_current_addr_sk`           AS `c_current_addr_sk`
    FROM (
      SELECT
        `cs_sold_date_sk`     AS `sold_date_sk`,
        `cs_bill_customer_sk` AS `customer_sk`,
        `cs_item_sk`          AS `item_sk`
      FROM `catalog_sales`
      UNION ALL
      SELECT
        `ws_sold_date_sk`     AS `sold_date_sk`,
        `ws_bill_customer_sk` AS `customer_sk`,
        `ws_item_sk`          AS `item_sk`
      FROM `web_sales`
    ) AS `cs_or_ws_sales`
    JOIN `item` AS `i`
      ON `cs_or_ws_sales`.`item_sk` = `i`.`i_item_sk`
    JOIN `date_dim` AS `d`
      ON `cs_or_ws_sales`.`sold_date_sk` = `d`.`d_date_sk`
    JOIN `customer` AS `c`
      ON `cs_or_ws_sales`.`customer_sk` = `c`.`c_customer_sk`
    WHERE
      `i`.`i_category` = 'Jewelry'
      AND `i`.`i_class` = 'consignment'
      AND `d`.`d_moy`   = 3
      AND `d`.`d_year`  = 1999
  ),
  `my_revenue` AS (
    SELECT
      `mc`.`c_customer_sk`,
      SUM(`ss`.`ss_ext_sales_price`) AS `revenue`
    FROM `my_customers` AS `mc`
    JOIN `store_sales` AS `ss`
      ON `mc`.`c_customer_sk` = `ss`.`ss_customer_sk`
    JOIN `customer_address` AS `ca`
      ON `mc`.`c_current_addr_sk` = `ca`.`ca_address_sk`
    JOIN `store` AS `s`
      ON `ca`.`ca_county` = `s`.`s_county`
     AND `ca`.`ca_state`  = `s`.`s_state`
    JOIN `date_dim` AS `d`
      ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    WHERE
      `d`.`d_month_seq` BETWEEN
        (SELECT DISTINCT `d2`.`d_month_seq` + 1
         FROM `date_dim` AS `d2`
         WHERE `d2`.`d_year` = 1999
           AND `d2`.`d_moy`  = 3)
      AND
        (SELECT DISTINCT `d3`.`d_month_seq` + 3
         FROM `date_dim` AS `d3`
         WHERE `d3`.`d_year` = 1999
           AND `d3`.`d_moy`  = 3)
    GROUP BY
      `mc`.`c_customer_sk`
  ),
  `segments` AS (
    SELECT
      CAST(`revenue`/50 AS SIGNED) AS `segment`
    FROM `my_revenue`
  )
SELECT
  `segment`,
  COUNT(*)         AS `num_customers`,
  `segment` * 50   AS `segment_base`
FROM `segments`
GROUP BY
  `segment`
ORDER BY
  `segment`,
  `num_customers`
LIMIT 100;
