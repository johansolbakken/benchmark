SELECT *
FROM title t
JOIN cast_info c
    ON c.movie_id = t.id
JOIN movie_info mi
    ON mi.movie_id = t.id
JOIN info_type it
    ON mi.info_type_id = it.id
JOIN person_info pi
    ON pi.person_id = c.person_id
JOIN name n
    ON n.id = c.person_id
JOIN movie_keyword mk
    ON mk.movie_id = t.id
JOIN keyword k
    ON k.id = mk.keyword_id
JOIN movie_link ml
    ON ml.movie_id = t.id
JOIN aka_title at
    ON at.movie_id = t.id
JOIN complete_cast cc
    ON cc.movie_id = t.id
JOIN movie_companies mc
    ON mc.movie_id = t.id
WHERE
    t.production_year = 2010
    AND lower(k.keyword) in ('action', 'drama')
ORDER BY c.id;
