WITH
  `ssr` AS (
    SELECT
      `s`.`s_store_id` AS `store_id`,
      SUM(`ss`.`ss_ext_sales_price`) AS `sales`,
      SUM(COALESCE(`sr`.`sr_return_amt`, 0)) AS `returns`,
      SUM(`ss`.`ss_net_profit` - COALESCE(`sr`.`sr_net_loss`, 0)) AS `profit`
    FROM `store_sales` AS `ss`
    LEFT JOIN `store_returns` AS `sr`
      ON `ss`.`ss_item_sk` = `sr`.`sr_item_sk`
     AND `ss`.`ss_ticket_number` = `sr`.`sr_ticket_number`
    JOIN `date_dim` AS `d`
      ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    JOIN `store` AS `s`
      ON `ss`.`ss_store_sk` = `s`.`s_store_sk`
    JOIN `item` AS `i`
      ON `ss`.`ss_item_sk` = `i`.`i_item_sk`
    JOIN `promotion` AS `p`
      ON `ss`.`ss_promo_sk` = `p`.`p_promo_sk`
    WHERE
      `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                      AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
      AND `i`.`i_current_price` > 50
      AND `p`.`p_channel_tv` = 'N'
    GROUP BY `s`.`s_store_id`
  ),
  `csr` AS (
    SELECT
      `cp`.`cp_catalog_page_id` AS `catalog_page_id`,
      SUM(`cs`.`cs_ext_sales_price`) AS `sales`,
      SUM(COALESCE(`cr`.`cr_return_amount`, 0)) AS `returns`,
      SUM(`cs`.`cs_net_profit` - COALESCE(`cr`.`cr_net_loss`, 0)) AS `profit`
    FROM `catalog_sales` AS `cs`
    LEFT JOIN `catalog_returns` AS `cr`
      ON `cs`.`cs_item_sk` = `cr`.`cr_item_sk`
     AND `cs`.`cs_order_number` = `cr`.`cr_order_number`
    JOIN `date_dim` AS `d`
      ON `cs`.`cs_sold_date_sk` = `d`.`d_date_sk`
    JOIN `catalog_page` AS `cp`
      ON `cs`.`cs_catalog_page_sk` = `cp`.`cp_catalog_page_sk`
    JOIN `item` AS `i`
      ON `cs`.`cs_item_sk` = `i`.`i_item_sk`
    JOIN `promotion` AS `p`
      ON `cs`.`cs_promo_sk` = `p`.`p_promo_sk`
    WHERE
      `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                      AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
      AND `i`.`i_current_price` > 50
      AND `p`.`p_channel_tv` = 'N'
    GROUP BY `cp`.`cp_catalog_page_id`
  ),
  `wsr` AS (
    SELECT
      `w`.`web_site_id` AS `web_site_id`,
      SUM(`ws`.`ws_ext_sales_price`) AS `sales`,
      SUM(COALESCE(`wr`.`wr_return_amt`, 0)) AS `returns`,
      SUM(`ws`.`ws_net_profit` - COALESCE(`wr`.`wr_net_loss`, 0)) AS `profit`
    FROM `web_sales` AS `ws`
    LEFT JOIN `web_returns` AS `wr`
      ON `ws`.`ws_item_sk` = `wr`.`wr_item_sk`
     AND `ws`.`ws_order_number` = `wr`.`wr_order_number`
    JOIN `date_dim` AS `d`
      ON `ws`.`ws_sold_date_sk` = `d`.`d_date_sk`
    JOIN `web_site` AS `w`
      ON `ws`.`ws_web_site_sk` = `w`.`web_site_sk`
    JOIN `item` AS `i`
      ON `ws`.`ws_item_sk` = `i`.`i_item_sk`
    JOIN `promotion` AS `p`
      ON `ws`.`ws_promo_sk` = `p`.`p_promo_sk`
    WHERE
      `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                      AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
      AND `i`.`i_current_price` > 50
      AND `p`.`p_channel_tv` = 'N'
    GROUP BY `w`.`web_site_id`
  )
SELECT
  `x`.`channel`,
  `x`.`id`,
  SUM(`x`.`sales`)   AS `sales`,
  SUM(`x`.`returns`) AS `returns`,
  SUM(`x`.`profit`)  AS `profit`
FROM (
  SELECT
    'store channel'               AS `channel`,
    CONCAT('store', `ssr`.`store_id`) AS `id`,
    `ssr`.`sales`,
    `ssr`.`returns`,
    `ssr`.`profit`
  FROM `ssr`
  UNION ALL
  SELECT
    'catalog channel'             AS `channel`,
    CONCAT('catalog_page', `csr`.`catalog_page_id`) AS `id`,
    `csr`.`sales`,
    `csr`.`returns`,
    `csr`.`profit`
  FROM `csr`
  UNION ALL
  SELECT
    'web channel'                 AS `channel`,
    CONCAT('web_site', `wsr`.`web_site_id`) AS `id`,
    `wsr`.`sales`,
    `wsr`.`returns`,
    `wsr`.`profit`
  FROM `wsr`
) AS `x`
GROUP BY `x`.`channel`, `x`.`id` WITH ROLLUP
ORDER BY `x`.`channel`, `x`.`id`
LIMIT 100;
