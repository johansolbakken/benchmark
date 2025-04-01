SELECT *
FROM title t
  LEFT OUTER JOIN kind_type kt ON kt.id = t.kind_id
  LEFT OUTER JOIN aka_title at ON at.movie_id = t.id
  LEFT OUTER JOIN movie_info mi ON mi.movie_id = t.id
  LEFT OUTER JOIN info_type mit ON mit.id = mi.info_type_id
  LEFT OUTER JOIN movie_info_idx mii ON mii.movie_id = t.id
  LEFT OUTER JOIN info_type miit ON miit.id = mii.info_type_id
  LEFT OUTER JOIN movie_keyword mk ON mk.movie_id = t.id
  LEFT OUTER JOIN keyword k ON k.id = mk.keyword_id
  LEFT OUTER JOIN movie_link ml ON ml.movie_id = t.id
  LEFT OUTER JOIN link_type lt ON lt.id = ml.link_type_id
  LEFT OUTER JOIN complete_cast cc ON cc.movie_id = t.id
  LEFT OUTER JOIN cast_info ci ON ci.movie_id = t.id
  LEFT OUTER JOIN role_type rt ON rt.id = ci.role_id
  LEFT OUTER JOIN comp_cast_type cct ON cct.id = ci.person_role_id
  LEFT OUTER JOIN name n ON n.id = ci.person_id
  LEFT OUTER JOIN aka_name an ON an.person_id = n.id
  LEFT OUTER JOIN person_info pi ON pi.person_id = n.id
  LEFT OUTER JOIN info_type pit ON pit.id = pi.info_type_id
  LEFT OUTER JOIN movie_companies mcomp ON mcomp.movie_id = t.id
  LEFT OUTER JOIN company_name cn ON cn.id = mcomp.company_id
  LEFT OUTER JOIN company_type ct ON ct.id = mcomp.company_type_id
WHERE lower(t.title) LIKE '%the%'
ORDER BY t.production_year
LIMIT 10000;
