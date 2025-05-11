SELECT
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_current_price`
FROM `item` AS `i`
JOIN `inventory` AS `inv`
  ON `inv`.`inv_item_sk` = `i`.`i_item_sk`
JOIN `date_dim` AS `d`
  ON `d`.`d_date_sk` = `inv`.`inv_date_sk`
JOIN `store_sales` AS `ss`
  ON `ss`.`ss_item_sk` = `i`.`i_item_sk`
WHERE `i`.`i_current_price` BETWEEN 30 AND 30 + 30
  AND `d`.`d_date` BETWEEN CAST('2002-05-30' AS DATE)
                      AND CAST('2002-05-30' AS DATE) + INTERVAL 60 DAY
  AND `i`.`i_manufact_id` IN (437,129,727,663)
  AND `inv`.`inv_quantity_on_hand` BETWEEN 100 AND 500
GROUP BY
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_current_price`
ORDER BY
  `i`.`i_item_id`
LIMIT 100;
