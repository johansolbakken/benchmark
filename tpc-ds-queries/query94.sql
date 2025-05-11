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
  ON `ws1`.`ws_web_site_sk` = `ws`.`web_site_sk`
WHERE
  `d`.`d_date` BETWEEN CAST('1999-05-01' AS DATE)
                  AND CAST('1999-05-01' AS DATE) + INTERVAL 60 DAY
  AND `ca`.`ca_state` = 'TX'
  AND `ws`.`web_company_name` = 'pri'
  AND EXISTS (
    SELECT 1
    FROM `web_sales` AS `ws2`
    WHERE `ws2`.`ws_order_number` = `ws1`.`ws_order_number`
      AND `ws2`.`ws_warehouse_sk` <> `ws1`.`ws_warehouse_sk`
  )
  AND NOT EXISTS (
    SELECT 1
    FROM `web_returns` AS `wr1`
    WHERE `wr1`.`wr_order_number` = `ws1`.`ws_order_number`
  )
ORDER BY `order_count`
LIMIT 100;
