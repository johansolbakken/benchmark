SELECT
  SUM(`ss`.`ss_quantity`)
FROM `store_sales` AS `ss`
JOIN `store` AS `s`
  ON `s`.`s_store_sk` = `ss`.`ss_store_sk`
JOIN `date_dim` AS `d`
  ON `ss`.`ss_sold_date_sk` = `d`.`d_date_sk`
JOIN `customer_demographics` AS `cd`
  ON `ss`.`ss_cdemo_sk` = `cd`.`cd_demo_sk`
JOIN `customer_address` AS `ca`
  ON `ss`.`ss_addr_sk` = `ca`.`ca_address_sk`
WHERE `d`.`d_year` = 1998
  AND (
    `cd`.`cd_marital_status` = 'M'
    AND `cd`.`cd_education_status` = '4 yr Degree'
    AND `ss`.`ss_sales_price` BETWEEN 100.00 AND 150.00
    OR `cd`.`cd_marital_status` = 'D'
    AND `cd`.`cd_education_status` = 'Primary'
    AND `ss`.`ss_sales_price` BETWEEN 50.00 AND 100.00
    OR `cd`.`cd_marital_status` = 'U'
    AND `cd`.`cd_education_status` = 'Advanced Degree'
    AND `ss`.`ss_sales_price` BETWEEN 150.00 AND 200.00
  )
  AND (
    `ca`.`ca_country` = 'United States'
    AND `ca`.`ca_state` IN ('KY', 'GA', 'NM')
    AND `ss`.`ss_net_profit` BETWEEN 0 AND 2000
    OR `ca`.`ca_country` = 'United States'
    AND `ca`.`ca_state` IN ('MT', 'OR', 'IN')
    AND `ss`.`ss_net_profit` BETWEEN 150 AND 3000
    OR `ca`.`ca_country` = 'United States'
    AND `ca`.`ca_state` IN ('WI', 'MO', 'WV')
    AND `ss`.`ss_net_profit` BETWEEN 50 AND 25000
  );
