SELECT
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_current_price`
FROM `item` AS `i`
JOIN `inventory` AS `inv`
  ON `inv`.`inv_item_sk` = `i`.`i_item_sk`
JOIN `date_dim` AS `d`
  ON `d`.`d_date_sk` = `inv`.`inv_date_sk`
JOIN `catalog_sales` AS `cs`
  ON `cs`.`cs_item_sk` = `i`.`i_item_sk`
WHERE `i`.`i_current_price` BETWEEN 22 AND 22 + 30
  AND `d`.`d_date` BETWEEN CAST('2001-06-02' AS DATE)
                      AND CAST('2001-06-02' AS DATE) + INTERVAL 60 DAY
  AND `i`.`i_manufact_id` IN (678, 964, 918, 849)
  AND `inv`.`inv_quantity_on_hand` BETWEEN 100 AND 500
GROUP BY
  `i`.`i_item_id`,
  `i`.`i_item_desc`,
  `i`.`i_current_price`
ORDER BY
  `i`.`i_item_id`
LIMIT 100;
