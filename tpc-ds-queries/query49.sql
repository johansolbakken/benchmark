SELECT
  t.channel,
  t.item,
  t.return_ratio,
  t.return_rank,
  t.currency_rank
FROM (
  /* Web channel */
  SELECT
    'web'       AS channel,
    web.item,
    web.return_ratio,
    web.return_rank,
    web.currency_rank
  FROM (
    SELECT
      in_web.item,
      in_web.return_ratio,
      in_web.currency_ratio,
      RANK() OVER (ORDER BY in_web.return_ratio)   AS return_rank,
      RANK() OVER (ORDER BY in_web.currency_ratio) AS currency_rank
    FROM (
      SELECT
        ws.ws_item_sk AS item,
        CAST(SUM(COALESCE(wr.wr_return_quantity,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(ws.ws_quantity,0)) AS DECIMAL(15,4)) AS return_ratio,
        CAST(SUM(COALESCE(wr.wr_return_amt,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(ws.ws_net_paid,0)) AS DECIMAL(15,4)) AS currency_ratio
      FROM web_sales AS ws
      LEFT JOIN web_returns AS wr
        ON ws.ws_order_number = wr.wr_order_number
       AND ws.ws_item_sk      = wr.wr_item_sk
      JOIN date_dim AS d
        ON ws.ws_sold_date_sk = d.d_date_sk
      WHERE
        wr.wr_return_amt > 10000
        AND ws.ws_net_profit > 1
        AND ws.ws_net_paid   > 0
        AND ws.ws_quantity   > 0
        AND d.d_year         = 2000
        AND d.d_moy          = 12
      GROUP BY ws.ws_item_sk
    ) AS in_web
  ) AS web
  WHERE web.return_rank   <= 10
     OR web.currency_rank <= 10

  UNION ALL

  /* Catalog channel */
  SELECT
    'catalog'       AS channel,
    catalog.item,
    catalog.return_ratio,
    catalog.return_rank,
    catalog.currency_rank
  FROM (
    SELECT
      in_cat.item,
      in_cat.return_ratio,
      in_cat.currency_ratio,
      RANK() OVER (ORDER BY in_cat.return_ratio)   AS return_rank,
      RANK() OVER (ORDER BY in_cat.currency_ratio) AS currency_rank
    FROM (
      SELECT
        cs.cs_item_sk AS item,
        CAST(SUM(COALESCE(cr.cr_return_quantity,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(cs.cs_quantity,0)) AS DECIMAL(15,4)) AS return_ratio,
        CAST(SUM(COALESCE(cr.cr_return_amount,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(cs.cs_net_paid,0)) AS DECIMAL(15,4)) AS currency_ratio
      FROM catalog_sales AS cs
      LEFT JOIN catalog_returns AS cr
        ON cs.cs_order_number = cr.cr_order_number
       AND cs.cs_item_sk     = cr.cr_item_sk
      JOIN date_dim AS d
        ON cs.cs_sold_date_sk = d.d_date_sk
      WHERE
        cr.cr_return_amount > 10000
        AND cs.cs_net_profit  > 1
        AND cs.cs_net_paid    > 0
        AND cs.cs_quantity    > 0
        AND d.d_year          = 2000
        AND d.d_moy           = 12
      GROUP BY cs.cs_item_sk
    ) AS in_cat
  ) AS catalog
  WHERE catalog.return_rank   <= 10
     OR catalog.currency_rank <= 10

  UNION ALL

  /* Store channel */
  SELECT
    'store'       AS channel,
    store.item,
    store.return_ratio,
    store.return_rank,
    store.currency_rank
  FROM (
    SELECT
      in_store.item,
      in_store.return_ratio,
      in_store.currency_ratio,
      RANK() OVER (ORDER BY in_store.return_ratio)   AS return_rank,
      RANK() OVER (ORDER BY in_store.currency_ratio) AS currency_rank
    FROM (
      SELECT
        sts.ss_item_sk AS item,
        CAST(SUM(COALESCE(sr.sr_return_quantity,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(sts.ss_quantity,0)) AS DECIMAL(15,4)) AS return_ratio,
        CAST(SUM(COALESCE(sr.sr_return_amt,0)) AS DECIMAL(15,4))
          / CAST(SUM(COALESCE(sts.ss_net_paid,0)) AS DECIMAL(15,4)) AS currency_ratio
      FROM store_sales AS sts
      LEFT JOIN store_returns AS sr
        ON sts.ss_ticket_number = sr.sr_ticket_number
       AND sts.ss_item_sk       = sr.sr_item_sk
      JOIN date_dim AS d
        ON sts.ss_sold_date_sk = d.d_date_sk
      WHERE
        sr.sr_return_amt  > 10000
        AND sts.ss_net_profit > 1
        AND sts.ss_net_paid   > 0
        AND sts.ss_quantity   > 0
        AND d.d_year          = 2000
        AND d.d_moy           = 12
      GROUP BY sts.ss_item_sk
    ) AS in_store
  ) AS store
  WHERE store.return_rank   <= 10
     OR store.currency_rank <= 10
) AS t
ORDER BY
  t.channel,
  t.return_rank,
  t.currency_rank,
  t.item
LIMIT 100;
