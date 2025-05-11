WITH `ws_wh` AS (
  SELECT
    `ws1`.`ws_order_number` AS `ws_order_number`
  FROM `web_sales` AS `ws1`
  JOIN `web_sales` AS `ws2`
    ON `ws1`.`ws_order_number` = `ws2`.`ws_order_number`
  WHERE `ws1`.`ws_warehouse_sk` <> `ws2`.`ws_warehouse_sk`
  GROUP BY `ws1`.`ws_order_number`
)
SELECT
  COUNT(DISTINCT `ws1`.`ws_order_number`) AS `order_count`,
  SUM(`ws1`.`ws_ext_ship_cost`)         AS `total_shipping_cost`,
  SUM(`ws1`.`ws_net_profit`)            AS `total_net_profit`
FROM `web_sales` AS `ws1`
JOIN `date_dim` AS `d`
  ON `ws1`.`ws_ship_date_sk` = `d`.`d_date_sk`
JOIN `customer_address` AS `ca`
  ON `ws1`.`ws_ship_addr_sk` = `ca`.`ca_address_sk`
JOIN `web_site` AS `ws`
  ON `ws1`.`ws_web_site_sk`  = `ws`.`web_site_sk`
WHERE
  `d`.`d_date` BETWEEN CAST('1999-05-01' AS DATE)
                  AND CAST('1999-05-01' AS DATE) + INTERVAL 60 DAY
  AND `ca`.`ca_state` = 'TX'
  AND `ws`.`web_company_name` = 'pri'
  AND `ws1`.`ws_order_number` IN (SELECT `ws_order_number` FROM `ws_wh`)
  AND `ws1`.`ws_order_number` IN (
    SELECT `wr`.`wr_order_number`
    FROM `web_returns` AS `wr`
    JOIN `ws_wh`
      ON `wr`.`wr_order_number` = `ws_wh`.`ws_order_number`
  )
ORDER BY `order_count`
LIMIT 100;
