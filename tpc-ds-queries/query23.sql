WITH
  `frequent_ss_items` AS (
    SELECT
      SUBSTR(`i`.`i_item_desc`, 1, 30) AS `itemdesc`,
      `i`.`i_item_sk`               AS `item_sk`,
      `d`.`d_date`                  AS `solddate`,
      COUNT(*)                      AS `cnt`
    FROM `store_sales` AS `ss`
    JOIN `date_dim`     AS `d` ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    JOIN `item`         AS `i` ON `ss`.`ss_item_sk`      = `i`.`i_item_sk`
    WHERE `d`.`d_year` IN (1999, 2000, 2001, 2002)
    GROUP BY SUBSTR(`i`.`i_item_desc`,1,30), `i`.`i_item_sk`, `d`.`d_date`
    HAVING COUNT(*) > 4
  ),
  `max_store_sales` AS (
    SELECT MAX(`csales`) AS `tpcds_cmax`
    FROM (
      SELECT
        `c`.`c_customer_sk`,
        SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) AS `csales`
      FROM `store_sales` AS `ss`
      JOIN `customer`    AS `c` ON `ss`.`ss_customer_sk`   = `c`.`c_customer_sk`
      JOIN `date_dim`   AS `d` ON `ss`.`ss_sold_date_sk`  = `d`.`d_date_sk`
      WHERE `d`.`d_year` IN (1999, 2000, 2001, 2002)
      GROUP BY `c`.`c_customer_sk`
    ) AS `store_customer_sales`
  ),
  `best_ss_customer` AS (
    SELECT
      `c`.`c_customer_sk`,
      SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) AS `ssales`
    FROM `store_sales` AS `ss`
    JOIN `customer`    AS `c` ON `ss`.`ss_customer_sk` = `c`.`c_customer_sk`
    GROUP BY `c`.`c_customer_sk`
    HAVING SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) > 0.95 * (SELECT `tpcds_cmax` FROM `max_store_sales`)
  )
SELECT
  SUM(`sales`) AS `total_sales`
FROM (
  SELECT
    `cs`.`cs_quantity` * `cs`.`cs_list_price` AS `sales`
  FROM `catalog_sales` AS `cs`
  JOIN `date_dim`      AS `d`  ON `cs`.`cs_sold_date_sk` = `d`.`d_date_sk`
  WHERE
    `d`.`d_year` = 1999
    AND `d`.`d_moy` = 1
    AND `cs`.`cs_item_sk`           IN (SELECT `item_sk`         FROM `frequent_ss_items`)
    AND `cs`.`cs_bill_customer_sk`  IN (SELECT `c_customer_sk`   FROM `best_ss_customer`)
  UNION ALL
  SELECT
    `ws`.`ws_quantity` * `ws`.`ws_list_price`
  FROM `web_sales`      AS `ws`
  JOIN `date_dim`      AS `d`  ON `ws`.`ws_sold_date_sk` = `d`.`d_date_sk`
  WHERE
    `d`.`d_year` = 1999
    AND `d`.`d_moy` = 1
    AND `ws`.`ws_item_sk`           IN (SELECT `item_sk`         FROM `frequent_ss_items`)
    AND `ws`.`ws_bill_customer_sk`  IN (SELECT `c_customer_sk`   FROM `best_ss_customer`)
) AS `combined_sales`
LIMIT 100;

WITH
  `frequent_ss_items` AS (
    SELECT
      SUBSTR(`i`.`i_item_desc`, 1, 30) AS `itemdesc`,
      `i`.`i_item_sk`               AS `item_sk`,
      `d`.`d_date`                  AS `solddate`,
      COUNT(*)                      AS `cnt`
    FROM `store_sales` AS `ss`
    JOIN `date_dim`     AS `d` ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    JOIN `item`         AS `i` ON `ss`.`ss_item_sk`      = `i`.`i_item_sk`
    WHERE `d`.`d_year` IN (1999, 2000, 2001, 2002)
    GROUP BY SUBSTR(`i`.`i_item_desc`,1,30), `i`.`i_item_sk`, `d`.`d_date`
    HAVING COUNT(*) > 4
  ),
  `max_store_sales` AS (
    SELECT MAX(`csales`) AS `tpcds_cmax`
    FROM (
      SELECT
        `c`.`c_customer_sk`,
        SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) AS `csales`
      FROM `store_sales` AS `ss`
      JOIN `customer`    AS `c` ON `ss`.`ss_customer_sk`   = `c`.`c_customer_sk`
      JOIN `date_dim`   AS `d` ON `ss`.`ss_sold_date_sk`  = `d`.`d_date_sk`
      WHERE `d`.`d_year` IN (1999, 2000, 2001, 2002)
      GROUP BY `c`.`c_customer_sk`
    ) AS `store_customer_sales`
  ),
  `best_ss_customer` AS (
    SELECT
      `c`.`c_customer_sk`,
      SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) AS `ssales`
    FROM `store_sales` AS `ss`
    JOIN `customer`    AS `c` ON `ss`.`ss_customer_sk` = `c`.`c_customer_sk`
    GROUP BY `c`.`c_customer_sk`
    HAVING SUM(`ss`.`ss_quantity` * `ss`.`ss_sales_price`) > 0.95 * (SELECT `tpcds_cmax` FROM `max_store_sales`)
  )
SELECT
  `x`.`c_last_name`,
  `x`.`c_first_name`,
  `x`.`sales`
FROM (
  SELECT
    `c`.`c_last_name`,
    `c`.`c_first_name`,
    SUM(`cs`.`cs_quantity` * `cs`.`cs_list_price`) AS `sales`
  FROM `catalog_sales` AS `cs`
  JOIN `customer`     AS `c` ON `cs`.`cs_bill_customer_sk` = `c`.`c_customer_sk`
  JOIN `date_dim`    AS `d` ON `cs`.`cs_sold_date_sk`    = `d`.`d_date_sk`
  WHERE
    `d`.`d_year` = 1999
    AND `d`.`d_moy` = 1
    AND `cs`.`cs_item_sk`          IN (SELECT `item_sk`       FROM `frequent_ss_items`)
    AND `cs`.`cs_bill_customer_sk` IN (SELECT `c_customer_sk` FROM `best_ss_customer`)
  GROUP BY `c`.`c_last_name`, `c`.`c_first_name`
  UNION ALL
  SELECT
    `c`.`c_last_name`,
    `c`.`c_first_name`,
    SUM(`ws`.`ws_quantity` * `ws`.`ws_list_price`) AS `sales`
  FROM `web_sales`      AS `ws`
  JOIN `customer`     AS `c` ON `ws`.`ws_bill_customer_sk` = `c`.`c_customer_sk`
  JOIN `date_dim`    AS `d` ON `ws`.`ws_sold_date_sk`    = `d`.`d_date_sk`
  WHERE
    `d`.`d_year` = 1999
    AND `d`.`d_moy` = 1
    AND `ws`.`ws_item_sk`          IN (SELECT `item_sk`       FROM `frequent_ss_items`)
    AND `ws`.`ws_bill_customer_sk` IN (SELECT `c_customer_sk` FROM `best_ss_customer`)
  GROUP BY `c`.`c_last_name`, `c`.`c_first_name`
) AS `x`
ORDER BY `x`.`c_last_name`, `x`.`c_first_name`, `x`.`sales`
LIMIT 100;
