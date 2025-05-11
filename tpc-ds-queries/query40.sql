SELECT
  `w`.`w_state`,
  `i`.`i_item_id`,
  SUM(
    CASE
      WHEN `d`.`d_date` < '1998-04-08' THEN `cs`.`cs_sales_price` - COALESCE(`cr`.`cr_refunded_cash`, 0)
      ELSE 0
    END
  ) AS `sales_before`,
  SUM(
    CASE
      WHEN `d`.`d_date` >= '1998-04-08' THEN `cs`.`cs_sales_price` - COALESCE(`cr`.`cr_refunded_cash`, 0)
      ELSE 0
    END
  ) AS `sales_after`
FROM `catalog_sales` AS `cs`
LEFT JOIN `catalog_returns` AS `cr`
  ON `cs`.`cs_order_number` = `cr`.`cr_order_number`
 AND `cs`.`cs_item_sk`     = `cr`.`cr_item_sk`
JOIN `warehouse` AS `w`
  ON `cs`.`cs_warehouse_sk` = `w`.`w_warehouse_sk`
JOIN `item` AS `i`
  ON `cs`.`cs_item_sk`       = `i`.`i_item_sk`
JOIN `date_dim` AS `d`
  ON `cs`.`cs_sold_date_sk`  = `d`.`d_date_sk`
WHERE
  `i`.`i_current_price` BETWEEN 0.99 AND 1.49
  AND `d`.`d_date` BETWEEN DATE_SUB('1998-04-08', INTERVAL 30 DAY)
                      AND DATE_ADD('1998-04-08', INTERVAL 30 DAY)
GROUP BY
  `w`.`w_state`,
  `i`.`i_item_id`
ORDER BY
  `w`.`w_state`,
  `i`.`i_item_id`
LIMIT 100;
