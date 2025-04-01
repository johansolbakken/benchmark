SELECT *
FROM title
    LEFT OUTER JOIN cast_info ON title.id = cast_info.movie_id
    LEFT OUTER JOIN name ON cast_info.person_id = name.id
    LEFT OUTER JOIN role_type ON cast_info.role_id = role_type.id
    LEFT OUTER JOIN movie_info ON title.id = movie_info.movie_id
    LEFT OUTER JOIN movie_keyword ON title.id = movie_keyword.movie_id
    LEFT OUTER JOIN movie_link ON title.id = movie_link.movie_id
    LEFT OUTER JOIN movie_companies ON title.id = movie_companies.movie_id
    LEFT OUTER JOIN complete_cast ON title.id = complete_cast.movie_id
    LEFT OUTER JOIN kind_type ON title.kind_id = kind_type.id
    LEFT OUTER JOIN info_type ON movie_info.info_type_id = info_type.id
    -- LEFT OUTER JOIN keyword ON movie_keyword.keyword_id = keyword.id
    LEFT OUTER JOIN link_type ON movie_link.link_type_id = link_type.id
    LEFT OUTER JOIN company_name ON movie_companies.company_id = company_name.id
    LEFT OUTER JOIN company_type ON movie_companies.company_type_id = company_type.id
WHERE title.production_year BETWEEN 1999 AND 2005
      AND lower(title.title) like '%star wars%'
      AND company_name.country_code = '[us]'
      AND lower(company_name.name) LIKE '%lucasfilm%'
ORDER BY title.title;
