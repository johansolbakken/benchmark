SELECT *
FROM title t
JOIN aka_title at ON at.movie_id = t.id AND at.id < 10
JOIN movie_info mi ON mi.movie_id = t.id AND mi.id < 10
JOIN movie_info_idx mii ON mii.movie_id = t.id AND mii.id < 1000
JOIN movie_keyword mk ON mk.movie_id = t.id AND mk.id < 1000
JOIN movie_link ml ON ml.movie_id = t.id AND ml.id < 1000
JOIN movie_companies mc ON mc.movie_id = t.id AND mc.id < 1000
JOIN complete_cast cc ON cc.movie_id = t.id AND cc.id < 1000
JOIN cast_info ci ON ci.movie_id = t.id AND ci.id < 1000
JOIN name n ON n.id = ci.person_id AND n.id < 1000
JOIN aka_name an ON an.person_id = n.id AND an.id < 1000
JOIN person_info pi ON pi.person_id = n.id AND pi.id < 1000
JOIN char_name cn ON cn.id = ci.role_id AND cn.id < 1000
JOIN role_type rt ON rt.id = ci.role_id AND rt.id < 1000
JOIN comp_cast_type cct ON cct.id = cc.subject_id AND cct.id < 1000
JOIN company_name cna ON cna.id = mc.company_id AND cna.id < 1000
JOIN company_type cty ON cty.id = mc.company_type_id AND cty.id < 1000
JOIN info_type it ON it.id = mi.info_type_id AND it.id < 1000
JOIN keyword k ON k.id = mk.keyword_id AND k.id < 1000
JOIN link_type lt ON lt.id = ml.link_type_id AND lt.id < 1000
JOIN kind_type kt ON kt.id = t.kind_id AND kt.id < 1000
ORDER BY t.production_year;
