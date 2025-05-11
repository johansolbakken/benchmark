SELECT
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_category`,
  `i`.`i_class`,
  `i`.`i_current_price`,
  SUM(`cs`.`cs_ext_sales_price`) AS `itemrevenue`,
  SUM(`cs`.`cs_ext_sales_price`) * 100
    / SUM(SUM(`cs`.`cs_ext_sales_price`)) OVER (PARTITION BY `i`.`i_class`) AS `revenueratio`
FROM `catalog_sales` AS `cs`
JOIN `item` AS `i`
  ON `cs`.`cs_item_sk` = `i`.`i_item_sk`
JOIN `date_dim` AS `d`
  ON `cs`.`cs_sold_date_sk` = `d`.`d_date_sk`
WHERE `i`.`i_category` IN ('Jewelry', 'Sports', 'Books')
  AND `d`.`d_date` BETWEEN CAST('2001-01-12' AS DATE)
                     AND CAST('2001-01-12' AS DATE) + INTERVAL 30 DAY
GROUP BY
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_category`,
  `i`.`i_class`,
  `i`.`i_current_price`
ORDER BY
  `i`.`i_category`,
  `i`.`i_class`,
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `revenueratio`
LIMIT 100;
