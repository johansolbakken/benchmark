SELECT t.title, t.production_year, cn.name AS company_name
FROM title t
JOIN kind_type kt ON t.kind_id = kt.id
JOIN movie_companies mc ON t.id = mc.movie_id
JOIN company_name cn ON mc.company_id = cn.id
JOIN company_type ctype ON mc.company_type_id = ctype.id
JOIN movie_info mi ON t.id = mi.movie_id
JOIN info_type it ON mi.info_type_id = it.id
JOIN cast_info ci ON t.id = ci.movie_id
JOIN name n ON ci.person_id = n.id
JOIN role_type rt ON ci.role_id = rt.id
WHERE kt.kind = 'movie'
AND cn.country_code = '[us]'
AND t.production_year BETWEEN 1990 AND 1999
ORDER BY t.production_year ASC, t.title ASC
LIMIT 10;