WITH
  `ss` AS (
    SELECT
      `s`.`s_store_sk` AS `s_store_sk`,
      SUM(`ss`.`ss_ext_sales_price`) AS `sales`,
      SUM(`ss`.`ss_net_profit`)      AS `profit`
    FROM `store_sales` AS `ss`
    JOIN `date_dim`   AS `d`
      ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
    JOIN `store`      AS `s`
      ON `ss`.`ss_store_sk`     = `s`.`s_store_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `s`.`s_store_sk`
  ),
  `sr` AS (
    SELECT
      `s`.`s_store_sk`      AS `s_store_sk`,
      SUM(`sr`.`sr_return_amt`) AS `returns`,
      SUM(`sr`.`sr_net_loss`)   AS `profit_loss`
    FROM `store_returns` AS `sr`
    JOIN `date_dim`      AS `d`
      ON `sr`.`sr_returned_date_sk` = `d`.`d_date_sk`
    JOIN `store`         AS `s`
      ON `sr`.`sr_store_sk`         = `s`.`s_store_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `s`.`s_store_sk`
  ),
  `cs` AS (
    SELECT
      `cs1`.`cs_call_center_sk` AS `cs_call_center_sk`,
      SUM(`cs1`.`cs_ext_sales_price`) AS `sales`,
      SUM(`cs1`.`cs_net_profit`)      AS `profit`
    FROM `catalog_sales` AS `cs1`
    JOIN `date_dim`      AS `d`
      ON `cs1`.`cs_sold_date_sk` = `d`.`d_date_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `cs1`.`cs_call_center_sk`
  ),
  `cr` AS (
    SELECT
      `cr1`.`cr_call_center_sk` AS `cr_call_center_sk`,
      SUM(`cr1`.`cr_return_amount`) AS `returns`,
      SUM(`cr1`.`cr_net_loss`)      AS `profit_loss`
    FROM `catalog_returns` AS `cr1`
    JOIN `date_dim`          AS `d`
      ON `cr1`.`cr_returned_date_sk` = `d`.`d_date_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `cr1`.`cr_call_center_sk`
  ),
  `ws` AS (
    SELECT
      `wp`.`wp_web_page_sk` AS `wp_web_page_sk`,
      SUM(`ws1`.`ws_ext_sales_price`) AS `sales`,
      SUM(`ws1`.`ws_net_profit`)      AS `profit`
    FROM `web_sales` AS `ws1`
    JOIN `date_dim`   AS `d`
      ON `ws1`.`ws_sold_date_sk` = `d`.`d_date_sk`
    JOIN `web_page`   AS `wp`
      ON `ws1`.`ws_web_page_sk`   = `wp`.`wp_web_page_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `wp`.`wp_web_page_sk`
  ),
  `wr` AS (
    SELECT
      `wp`.`wp_web_page_sk` AS `wp_web_page_sk`,
      SUM(`wr1`.`wr_return_amt`) AS `returns`,
      SUM(`wr1`.`wr_net_loss`)   AS `profit_loss`
    FROM `web_returns` AS `wr1`
    JOIN `date_dim`     AS `d`
      ON `wr1`.`wr_returned_date_sk` = `d`.`d_date_sk`
    JOIN `web_page`     AS `wp`
      ON `wr1`.`wr_web_page_sk`       = `wp`.`wp_web_page_sk`
    WHERE `d`.`d_date` BETWEEN CAST('1998-08-04' AS DATE)
                         AND CAST('1998-08-04' AS DATE) + INTERVAL 30 DAY
    GROUP BY `wp`.`wp_web_page_sk`
  )
SELECT
  `x`.`channel`,
  `x`.`id`,
  SUM(`x`.`sales`)   AS `sales`,
  SUM(`x`.`returns`) AS `returns`,
  SUM(`x`.`profit`)  AS `profit`
FROM (
  SELECT
    'store channel'                      AS `channel`,
    `ss`.`s_store_sk`                    AS `id`,
    `ss`.`sales`,
    COALESCE(`sr`.`returns`, 0)          AS `returns`,
    (`ss`.`profit` - COALESCE(`sr`.`profit_loss`, 0)) AS `profit`
  FROM `ss`
  LEFT JOIN `sr`
    ON `ss`.`s_store_sk` = `sr`.`s_store_sk`

  UNION ALL

  SELECT
    'catalog channel'                    AS `channel`,
    `cs`.`cs_call_center_sk`             AS `id`,
    `cs`.`sales`,
    COALESCE(`cr`.`returns`, 0)          AS `returns`,
    (`cs`.`profit` - COALESCE(`cr`.`profit_loss`, 0)) AS `profit`
  FROM `cs`
  LEFT JOIN `cr`
    ON `cs`.`cs_call_center_sk` = `cr`.`cr_call_center_sk`

  UNION ALL

  SELECT
    'web channel'                        AS `channel`,
    `ws`.`wp_web_page_sk`                AS `id`,
    `ws`.`sales`,
    COALESCE(`wr`.`returns`, 0)          AS `returns`,
    (`ws`.`profit` - COALESCE(`wr`.`profit_loss`, 0)) AS `profit`
  FROM `ws`
  LEFT JOIN `wr`
    ON `ws`.`wp_web_page_sk` = `wr`.`wp_web_page_sk`
) AS `x`
GROUP BY `channel`, `id` WITH ROLLUP
ORDER BY `channel`, `id`
LIMIT 100;
