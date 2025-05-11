SELECT
  SUM(`ws`.`ws_ext_discount_amt`) AS `excess_discount_amount`
FROM `web_sales` AS `ws`
JOIN `item` AS `i`
  ON `ws`.`ws_item_sk` = `i`.`i_item_sk`
JOIN `date_dim` AS `d`
  ON `ws`.`ws_sold_date_sk` = `d`.`d_date_sk`
WHERE
  `i`.`i_manufact_id` = 269
  AND `d`.`d_date` BETWEEN CAST('1998-03-18' AS DATE)
                     AND CAST('1998-03-18' AS DATE) + INTERVAL 90 DAY
  AND `ws`.`ws_ext_discount_amt` > (
    SELECT
      1.3 * AVG(`ws2`.`ws_ext_discount_amt`)
    FROM `web_sales` AS `ws2`
    JOIN `date_dim` AS `d2`
      ON `ws2`.`ws_sold_date_sk` = `d2`.`d_date_sk`
    WHERE
      `ws2`.`ws_item_sk` = `i`.`i_item_sk`
      AND `d2`.`d_date` BETWEEN CAST('1998-03-18' AS DATE)
                         AND CAST('1998-03-18' AS DATE) + INTERVAL 90 DAY
  )
ORDER BY `excess_discount_amount`
LIMIT 100;
